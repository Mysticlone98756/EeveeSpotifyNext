import Foundation

enum LyricsSource: Int, CaseIterable, CustomStringConvertible {
    case genius
    case lrclib
    case musixmatch
    case petit
    case notReplaced
    
    // Sources offered in the picker. Genius and LRCLIB are free (no token); Musixmatch
    // needs a user token; PetitLyrics is mostly Japanese. Track metadata is fetched on
    // 9.1.x (player / captured access token), so the metadata-based sources work too.
    public static var allCases: [LyricsSource] {
        return [.genius, .lrclib, .musixmatch, .petit]
    }

    // swift 5.8 compatible
    var description: String {
    switch self {
    case .genius:
        return "Genius"
    case .lrclib:
        return "LRCLIB"
    case .musixmatch:
        return "Musixmatch"
    case .petit:
        return "PetitLyrics"
    case .notReplaced:
        return "Spotify"
    }
    }

    
    var isReplacingLyrics: Bool { self != .notReplaced }
    
    // Genius is the default: free, no token required — works out of the box.
    static var defaultSource: LyricsSource {
        .genius
    }
}
