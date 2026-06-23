import Foundation

// Forward-compatibility helper. Orion `fatalError`s when a hook group targets a
// class that no longer exists (this is exactly what crashed the tweak when Spotify
// 9.1.58 removed ProfileSettingsSection/RootSettingsViewController). HookGuard lets
// us (a) only activate a group when its target classes are present, skipping with a
// log instead of crashing, and (b) record a compatibility report we can show in the
// Debug settings so a future Spotify change is diagnosable in-app, without reversing.
enum HookGuard {
    struct Entry: Identifiable {
        let id = UUID()
        let label: String
        let classes: [String]
        let missing: [String]
        let activated: Bool
        var present: Bool { missing.isEmpty }
    }

    private(set) static var entries: [Entry] = []

    private static func missingClasses(_ classes: [String]) -> [String] {
        classes.filter { NSClassFromString($0) == nil }
    }

    // Activates `body` only if every required class exists; otherwise skips (no crash).
    @discardableResult
    static func activate(_ label: String, requires classes: [String], _ body: () -> Void) -> Bool {
        let missing = missingClasses(classes)
        if missing.isEmpty {
            body()
            entries.append(Entry(label: label, classes: classes, missing: [], activated: true))
            writeDebugLog("[GUARD] activated \(label)")
            return true
        } else {
            entries.append(Entry(label: label, classes: classes, missing: missing, activated: false))
            writeDebugLog("[GUARD] SKIPPED \(label) — missing: \(missing.joined(separator: ", "))")
            return false
        }
    }

    // Records class presence for the compatibility report without gating anything
    // (used for groups we still activate unconditionally because they currently work).
    static func note(_ label: String, classes: [String]) {
        let missing = missingClasses(classes)
        entries.append(Entry(label: label, classes: classes, missing: missing, activated: true))
        if !missing.isEmpty {
            writeDebugLog("[COMPAT] \(label) — missing class(es): \(missing.joined(separator: ", "))")
        }
    }

    static func reset() {
        entries.removeAll()
    }

    static var summary: String {
        let present = entries.filter { $0.present }.count
        return "\(present)/\(entries.count) OK"
    }
}
