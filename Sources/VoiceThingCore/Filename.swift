import Foundation

public enum Filename {
    public static func safeComponent(_ rawValue: String, fallback: String = "clip") -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }

        let compacted = String(scalars)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))

        let base = compacted.isEmpty ? fallback : compacted
        return String(base.prefix(80))
    }
}
