import Foundation

/// Validates a tunnel name against `[A-Za-z0-9_-]{1,15}`. Must match the helper-side
/// `validate_name` check exactly — any drift here lets invalid names through the app
/// only to be rejected by the helper, or vice-versa.
public func validatedTunnelName(_ s: String) -> String? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.range(of: #"^[A-Za-z0-9_-]{1,15}$"#, options: .regularExpression) != nil ? trimmed : nil
}
