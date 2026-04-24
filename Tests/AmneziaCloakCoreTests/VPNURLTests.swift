import XCTest
@testable import AmneziaCloakCore

final class VPNURLTests: XCTestCase {

    // Fixture: valid Amnezia vpn:// share link generated from a fabricated AWG
    // config with inner protocol key `"awg"` (matches amnezia-client upstream).
    private let validModernURL =
        "vpn://AAADhnjadVPRbtowFP0V5GeWkoQyGmkPHZ1UNqlCYm8EITe-DKvBtmyHliH-fdf2RYFKs6Mk5xzn-B7bObFGK8-lAutYtTr1kFWM7xX8lfwLf__DhizcqxNrufMbHLWVCNmpZs95zapBzfAxxMdzkWBBsEywJDhOcJzgzybBe4J7qYgYXRj-QfajEXFLmrDM6bNlcRmSUxF73xFVfp0kymBC6Twov3kDMBveygNQqeTTtDLI0lzssskkXjeysfKAFsc06BHbrdy99up3bNfqXHzmHdgD2NuvZtioaPfW00_YEr3Tzr_wPZWfP0yz-zzDBcoovtHWB20yLh6mgeBtq99BYDQX-FXNRlnsd7SmVRXe1rHSuLfJejVXHuyWN7Cua7XA5NzDLzgOvg1i8Fo9CmHBOST65borC1SeXpbITrPYEeO1WgDY6NS9trJJRjFtrX4oYbRUPjhdBapihjBRijBfhLn66tGXnfF0hsh4HuNohN5y5QKH26W9RqUTBnnpfu-kFQtu_XFGh9jbDs7n9ZAJ2PKu9bP__gICXGOl8VIr1Lbyw3cWzE4rCKJyObIUOBEFEhgkdCQu2xbIq4js_A9fSweN"

    // Same config but inner protocol key is the legacy `"amnezia-awg"`.
    private let validLegacyURL =
        "vpn://AAADjnjadVPRbtowFP0V5GeWkoQyGmkPHZ1UNqlCYm8EITe-DKvBtmyHliH-fdf2RYFKsyM55xzn-B7bObFGK8-lAutYtTr1kFWM7xX8lfwLf__DhjeoOrGWO7_B2VuJkJ1q9pzXrBrUDIchDs9FggXBMsGS4DjBcYI_mwTvCe6lImJ0YfgH2Y9GxC1pwTKnz5bFZUpORex9R1T5dZIog0ml86D85g3AbHgrD0Clkk_TyiBLc7HLJpP43MjGygNaHNOkR2y3cvfaq9-xXatz8Zl3YA9gb7-aYaOi3VtPP2FL9E47_8L3VH7-MM3u8ww3KKP4RlsftMm4eJgGgretfgeB0VzgVzUbZbHf0Z5WVXhbx0rj2Sbr1Vx5sFvewLqu1QKTcw-_4Dj4NojBa_UohAXnkOi3664sUHl6WSI7zWJHjM9qAWCjU_fayiYZxbS1-qGE0VL54HQVqIoZwkIpwnwR1uqrR192xlsaIuN9jLMResuVCxwel_YalU4Y5KX7vZNWLLj1xxldYm87OJ_XQyZgy7vWz_77KwhwjZXGS61Q28oP31kwO60giMrlyFLgRBRIYJDQkbgcWyCvIrLzPzVICp8"

    func testDecodesModernInnerKey() {
        let parsed = VPNURL.parse(validModernURL)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "fixturephone")
        XCTAssertTrue(parsed?.conf.contains("[Interface]") ?? false)
        XCTAssertTrue(parsed?.conf.contains("Endpoint = 198.51.100.1:64298") ?? false)
    }

    func testDecodesLegacyInnerKey() {
        // Fallback path — some third-party generators still emit `amnezia-awg`
        // as the inner protocol key. Must decode successfully.
        let parsed = VPNURL.parse(validLegacyURL)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "fixturephone")
        XCTAssertTrue(parsed?.conf.contains("[Interface]") ?? false)
    }

    func testRejectsMissingPrefix() {
        XCTAssertNil(VPNURL.parse("https://example.com"))
        XCTAssertNil(VPNURL.parse("AAADhnjadVPRbtowFP0"))
    }

    func testRejectsGarbageBody() {
        XCTAssertNil(VPNURL.parse("vpn://not-base64-at-all!!!"))
        XCTAssertNil(VPNURL.parse("vpn://AAAA")) // 4 bytes, no payload
    }

    // Exercises the description → name sanitizer directly.
    func testSanitizeTunnelName() {
        XCTAssertEqual(VPNURL.sanitizedTunnelName("My Phone!"), "MyPhone")
        XCTAssertEqual(VPNURL.sanitizedTunnelName(""), "imported")
        XCTAssertEqual(VPNURL.sanitizedTunnelName("!!!"), "imported")
        // 20-char input → 15-char clip.
        XCTAssertEqual(VPNURL.sanitizedTunnelName("abcdefghij1234567890"), "abcdefghij12345")
    }
}
