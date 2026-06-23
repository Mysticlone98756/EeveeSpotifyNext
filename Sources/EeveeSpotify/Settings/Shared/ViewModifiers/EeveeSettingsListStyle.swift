import SwiftUI

// Unified look for every EeveeSpotify settings screen: modern inset-grouped cards
// plus a bottom inset so the last rows scroll clear of Spotify's floating
// now-playing / tab bar (otherwise the bottom items are hidden behind it).
struct EeveeSettingsListStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .listStyle(.insetGrouped)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 92)
                }
        } else {
            content
                .listStyle(.insetGrouped)
        }
    }
}

extension View {
    func eeveeSettingsListStyle() -> some View {
        modifier(EeveeSettingsListStyle())
    }
}
