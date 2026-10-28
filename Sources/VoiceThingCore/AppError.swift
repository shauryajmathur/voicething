import Foundation

public enum AppError: LocalizedError, Equatable {
    case missingAPIKey
    case unauthorized
    case invalidResponse
    case badStatus(Int)
    case invalidClipURL
    case downloadFailed
    case conversionFailed
    case normalizationFailed
    case targetUnavailable
    case accessibilityPermissionNeeded
    case instagramVoice(String)

    public var errorDescription: String? {
        switch self {
        case .instagramVoice(let message):
            return message
        case .missingAPIKey:
            return "No API key is needed."
        case .unauthorized:
            return "The sound source rejected the request."
        case .invalidResponse:
            return "The sound source returned an unreadable response."
        case .badStatus(let status):
            return "The sound source returned HTTP \(status)."
        case .invalidClipURL:
            return "This clip does not include a valid audio URL."
        case .downloadFailed:
            return "Could not download the audio clip."
        case .conversionFailed:
            return "Could not convert the clip to M4A."
        case .normalizationFailed:
            return "Could not normalize the clip volume."
        case .targetUnavailable:
            return "Open a chat with a voice recorder, then choose a sound again."
        case .accessibilityPermissionNeeded:
            return "Allow Accessibility access to operate your chat’s voice recorder."
        }
    }
}
