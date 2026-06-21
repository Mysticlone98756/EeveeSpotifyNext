import Orion
import Intents

class INMediaItemHook: ClassHook<INMediaItem> {
    typealias Group = BasePremiumPatchingGroup
    
    func identifier() -> String {
        let identifier = orig.identifier()

        guard identifier.contains("play-command") else {
            return identifier
        }

        // Every step below is best-effort: a malformed identifier must never crash
        // the app, so any failure returns the original identifier unchanged.
        let components = identifier.components(separatedBy: ":")
        guard
            components.count > 2,
            let jsonData = Data(base64Encoded: components[2]),
            var json = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any]
        else {
            return identifier
        }

        guard
            let feedbackDetails = json["feedback_details"] as? [String: Any],
            feedbackDetails["restriction"] as? String == "play-as-radio",
            var context = json["context"] as? [String: Any],
            let urlString = context["url"] as? String
        else {
            return identifier
        }

        context["url"] = urlString.removeMatches(":station")
        json["context"] = context

        guard let newData = try? JSONSerialization.data(withJSONObject: json) else {
            return identifier
        }

        return "spotify:play-command:\(newData.base64EncodedString())"
    }
}
