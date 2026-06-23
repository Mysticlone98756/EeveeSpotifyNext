import Orion
import Foundation

// On Spotify 9.1.x the plan/premium views (the "Premium" tab + the "your plan"
// card) load via pam-view-service Connect-RPC calls over async URLSession
// (URLSession.data(for:)) — they don't go through SPTDataLoaderService nor the
// completion-handler dataTask API, so neither the request hooks nor a
// dataTaskWithRequest:completionHandler: hook can see them.
//
// We intercept at the URL Loading System level with a URLProtocol (catches async,
// delegate and completion-handler requests alike) and replace the protobuf body
// with the tweak's generated EeveeSpotify plan data.
//
// Endpoints (9.1.58):
//   GET  /pam-view-service/v1/GetPremiumPlanRow
//   POST /pam-view-service/spotify.pam.v2.PamViewService/GetYourPremiumBadge
//   POST /pam-view-service/spotify.pam.v2.PamViewService/GetPlanOverview

private func planEndpointKind(_ path: String) -> String? {
    if path.contains("GetPremiumPlanRow") { return "row" }
    if path.contains("GetYourPremiumBadge") { return "badge" }
    if path.contains("GetPlanOverview") { return "overview" }
    if path.contains("premium-destination-hubs") { return "hub" }
    // On 9.1.x the RemoteConfig customize that would disable these goes through async
    // URLSession with a POST body we can't recover (re-issuing returns empty), so we
    // block the free-tier endpoints directly:
    //   capping-api  — drives the playback time-cap (tracks lag and auto-skip)
    //   ad-logic / ads / leavebehinds — serve free-tier audio & display ads
    if path.contains("capping-api") || path.contains("CappingApi")
        || path.contains("/ad-logic/")
        || path.contains("/ads/v")
        || path.contains("leavebehinds/ads") {
        return "block"
    }
    return nil
}

private func patchedPlanData(kind: String, original: Data?) -> Data? {
    do {
        switch kind {
        case "row":
            let row = (original.flatMap { try? PremiumPlanRow(serializedBytes: $0) }) ?? PremiumPlanRow()
            return try getPremiumPlanRowData(originalPremiumPlanRow: row)
        case "badge":
            return try getPremiumPlanBadge()
        case "overview":
            return try getPlanOverviewData()
        case "hub":
            return patchedPremiumHub(original) ?? original
        default:
            return original
        }
    } catch {
        writeDebugLog("[PLAN] modify FAILED (\(kind)): \(error)")
        return original
    }
}

// The Premium-tab page (premium-destination-hubs/v2/page) is a Hubs JSON page that
// for a free account is the "buy Premium" upsell. Rewrite its header to EeveeSpotify
// branding and drop the upsell body components so it no longer shows purchase cards.
private func patchedPremiumHub(_ original: Data?) -> Data? {
    guard
        let data = original,
        var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else {
        return original
    }

    if var header = json["header"] as? [String: Any] {
        if var text = header["text"] as? [String: Any] {
            text["title"] = "Eevee Premium"
            text["subtitle"] = ""
            header["text"] = text
        }
        json["header"] = header
    }

    // Remove the upsell cards / purchase CTAs.
    json["body"] = []
    json["overlays"] = []

    return (try? JSONSerialization.data(withJSONObject: json)) ?? original
}

final class EeveePlanURLProtocol: URLProtocol {
    private static let handledKey = "EeveePlanHandled"
    private var innerTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        guard
            EeveeSpotify.hookTarget == .v91,
            UserDefaults.patchType.isPatching,
            URLProtocol.property(forKey: handledKey, in: request) == nil,
            let path = request.url?.path,
            planEndpointKind(path) != nil
        else {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        // Mark so the re-issued request isn't intercepted again (no recursion).
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutable)

        let kind = planEndpointKind(request.url?.path ?? "") ?? ""
        writeDebugLog("[PLAN-PROTO] handling \(kind) \(request.url?.path ?? "?")")

        // Blocked endpoints (e.g. capping-api): return a synthetic empty 200 without
        // hitting the network, so the free-tier consumption/cap is never reported.
        if kind == "block" {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/2",
                headerFields: ["Content-Type": "application/grpc-web+proto"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        innerTask = URLSession.shared.dataTask(with: mutable as URLRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                writeDebugLog("[PLAN-PROTO] \(kind) network error: \(error)")
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            let newData = patchedPlanData(kind: kind, original: data) ?? data ?? Data()
            writeDebugLog("[PLAN-PROTO] \(kind) orig=\(data?.count ?? -1) -> served \(newData.count) bytes")

            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            self.client?.urlProtocol(self, didLoad: newData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        innerTask?.resume()
    }

    override func stopLoading() {
        innerTask?.cancel()
    }
}

// Registers the interceptor for URLSession.shared / default-config sessions.
func registerPlanInterceptor() {
    URLProtocol.registerClass(EeveePlanURLProtocol.self)
    writeDebugLog("[PLAN-PROTO] registered")
}

// Inject the protocol into custom URLSessionConfigurations too (Spotify uses its
// own configured sessions for spclient, which ignore the global registerClass).
class URLSessionConfigurationProtocolHook: ClassHook<URLSessionConfiguration> {
    func protocolClasses() -> [AnyClass]? {
        guard EeveeSpotify.hookTarget == .v91 else {
            return orig.protocolClasses()
        }
        var classes: [AnyClass] = [EeveePlanURLProtocol.self]
        if let existing = orig.protocolClasses() {
            classes.append(contentsOf: existing)
        }
        return classes
    }
}
