import Foundation
import SwiftUI
import libroot

class BundleHelper {
    private let bundleName = "EeveeSpotify"
    
    // Make properties optional to prevent init crash
    private var bundle: Bundle?
    private var enBundle: Bundle?
    
    static let shared = BundleHelper()

    // Find EeveeSpotify.bundle across the ways the tweak gets installed:
    //   1) inside the app bundle (injected IPA: cyan/ivinject copy it to the .app)
    //   2) next to the loaded tweak dylib (LiveContainer Tweaks folder / loose dylib)
    //   3) the jailbreak filesystem path
    // Without this the localized strings fall back to raw keys (e.g. "clear_debug_log").
    private static func locateBundle(named name: String) -> Bundle? {
        // 1. Inside the running app bundle.
        if let path = Bundle.main.path(forResource: name, ofType: "bundle"),
           let b = Bundle(path: path) {
            NSLog("[EeveeSpotify] Loaded bundle from app: \(path)")
            return b
        }

        // 2. Same directory as this dylib (#dsohandle -> dladdr -> dli_fname).
        var info = dl_info()
        if dladdr(#dsohandle, &info) != 0, let fname = info.dli_fname {
            let dylibDir = (String(cString: fname) as NSString).deletingLastPathComponent
            let path = (dylibDir as NSString).appendingPathComponent("\(name).bundle")
            if let b = Bundle(path: path) {
                NSLog("[EeveeSpotify] Loaded bundle next to dylib: \(path)")
                return b
            }
        }

        // 3. Jailbreak filesystem path.
        let jbPath = jbRootPath("/Library/Application Support/\(name).bundle")
        if let b = Bundle(path: jbPath) {
            NSLog("[EeveeSpotify] Loaded bundle from filesystem: \(jbPath)")
            return b
        }

        NSLog("[EeveeSpotify] ERROR: Could not find \(name).bundle!")
        return nil
    }
    
    private init() {
        self.bundle = BundleHelper.locateBundle(named: bundleName)
        
        // Load English localization if available
        if let b = self.bundle, let enPath = b.path(forResource: "en", ofType: "lproj"),
           let enB = Bundle(path: enPath) {
            self.enBundle = enB
        } else {
            NSLog("[EeveeSpotify] WARNING: Could not load en.lproj from bundle")
            self.enBundle = nil
        }
    }
    
    func uiImage(_ name: String) -> UIImage? {
        guard let bundle = self.bundle else { return nil }
        
        if let path = bundle.path(forResource: name, ofType: "png") {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
    
    func localizedString(_ key: String) -> String {
        guard let bundle = self.bundle else { return key }

        let value = bundle.localizedString(forKey: key, value: "No translation", table: nil)
        
        if value != "No translation" {
            return value
        }
        
        return enBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }
    
    func resolveConfiguration() throws -> ResolveConfiguration {
        guard let bundle = self.bundle,
              let url = bundle.url(forResource: "resolveconfiguration", withExtension: "bnk") else {
            throw NSError(domain: "EeveeSpotify", code: 404, userInfo: [NSLocalizedDescriptionKey: "Configuration not found"])
        }
        
        return try ResolveConfiguration(
            serializedBytes: try Data(contentsOf: url)
        )
    }
}
