import Foundation
import Compression

public enum VPNURL {
    public struct Parsed {
        public let name: String
        public let conf: String
    }

    /// Decode an Amnezia `vpn://` share link to a raw AmneziaWG `.conf` plus a
    /// tunnel name derived from the link's `description`.
    ///
    /// Format (matches Qt's `qCompress` consumed by amnezia-client):
    ///   `vpn://` + base64url( BE-uint32 uncompressed-size ‖ zlib-stream )
    ///
    /// The JSON inside keys the nested protocol object as `"awg"` (lowercased
    /// `Proto::Awg` enum). Older / third-party exports sometimes use
    /// `"amnezia-awg"` — both are accepted.
    public static func parse(_ url: String) -> Parsed? {
        guard url.hasPrefix("vpn://") else { return nil }

        var b64 = String(url.dropFirst("vpn://".count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }

        // Layout: [4-byte BE uncompressed-size | qCompress][zlib stream].
        // zlib stream = [2-byte header RFC 1950][raw DEFLATE RFC 1951][4-byte adler32].
        // Apple's Compression framework `COMPRESSION_ZLIB` decodes raw DEFLATE (despite
        // the name), so we strip the 2-byte header and 4-byte checksum before feeding it.
        guard let raw = Data(base64Encoded: b64), raw.count > 4 + 2 + 4 else { return nil }
        let expectedSize = raw.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
        let deflatePayload = raw.subdata(in: (4 + 2)..<(raw.count - 4))
        guard let decompressed = zlibDecompress(deflatePayload, expectedSize: expectedSize) else { return nil }

        guard let obj = try? JSONSerialization.jsonObject(with: decompressed) as? [String: Any],
              let containers = obj["containers"] as? [[String: Any]],
              let container = containers.first(where: { ($0["container"] as? String) == "amnezia-awg" })
        else { return nil }

        let awg = (container["awg"] as? [String: Any])
            ?? (container["amnezia-awg"] as? [String: Any])
            ?? [:]

        guard let lastStr = awg["last_config"] as? String,
              let inner = try? JSONSerialization.jsonObject(with: Data(lastStr.utf8)) as? [String: Any]
        else { return nil }

        let conf = (inner["config"] as? String) ?? ""
        let description = (obj["description"] as? String) ?? "imported"
        let name = sanitizedTunnelName(description)
        return Parsed(name: name, conf: conf)
    }

    /// Mirrors the sanitation pass in the legacy Python implementation: keep
    /// ASCII letters / digits / `_` / `-`, clip to 15, fall back to `"imported"`.
    static func sanitizedTunnelName(_ raw: String) -> String {
        let filtered = raw.unicodeScalars.filter { scalar in
            (scalar >= "A" && scalar <= "Z")
                || (scalar >= "a" && scalar <= "z")
                || (scalar >= "0" && scalar <= "9")
                || scalar == "_" || scalar == "-"
        }
        let clipped = String(String.UnicodeScalarView(filtered.prefix(15)))
        return clipped.isEmpty ? "imported" : clipped
    }

    /// Raw DEFLATE decompression via Apple's Compression framework. Despite the
    /// name `COMPRESSION_ZLIB`, the decoder wants RFC 1951 raw DEFLATE with no
    /// zlib wrapper — the caller is responsible for stripping the 2-byte zlib
    /// header and 4-byte adler32 trailer.
    private static func zlibDecompress(_ deflateData: Data, expectedSize: Int) -> Data? {
        // Trust the 4-byte qCompress size prefix for buffer sizing, with a generous
        // floor for robustness against malformed inputs.
        let bufferSize = max(expectedSize, 256 * 1024)
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dst.deallocate() }

        let written = deflateData.withUnsafeBytes { srcBuf -> Int in
            guard let src = srcBuf.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(dst, bufferSize, src, deflateData.count, nil, COMPRESSION_ZLIB)
        }
        guard written > 0 else { return nil }
        return Data(bytes: dst, count: written)
    }
}
