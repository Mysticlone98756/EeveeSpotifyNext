import UIKit

class URLSessionHelper {
    static let shared = URLSessionHelper()
    
    private var requestsMap: [URL:Data]
    // requestsMap is read/written from URLSession delegate callbacks that can run
    // concurrently — guard every access to avoid a data race / crash.
    private let lock = NSLock()

    private init() {
        self.requestsMap = [:]
    }
    
    static var DarwinVersion: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let dv = String(
            bytes: Data(bytes: &sysinfo.release, count: Int(_SYS_NAMELEN)), 
            encoding: .ascii
        )!.trimmingCharacters(in: .controlCharacters)
        return "Darwin/\(dv)"
    }
    
    static var CFNetworkVersion: String {
        let dictionary = Bundle(identifier: "com.apple.CFNetwork")?.infoDictionary!
        let version = dictionary?["CFBundleShortVersionString"] as! String
        return "CFNetwork/\(version)"
    }
    
    func setOrAppend(_ data: Data, for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        var loadedData = requestsMap[url] ?? Data()
        loadedData.append(data)

        requestsMap[url] = loadedData
    }

    func obtainData(for url: URL) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        return requestsMap.removeValue(forKey: url)
    }
}
