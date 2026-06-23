import SwiftUI
import UIKit 

class EeveeSettingsViewController: SPTPageViewController {
    let frame: CGRect
    let settingsView: AnyView
    
    init(_ frame: CGRect, settingsView: AnyView, navigationTitle: String) {
        self.frame = frame
        self.settingsView = settingsView
        super.init(nibName: nil, bundle: nil)
        
        title = navigationTitle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let hostingController = UIHostingController(rootView: settingsView)

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)

        // Pin with Auto Layout (instead of a fixed frame) so SwiftUI receives the
        // correct safe-area insets and the list can scroll its content clear of the
        // navigation bar and the home indicator.
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController.didMove(toParent: self)
    }
    
    @objc func openRepositoryUrl(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://github.com/w3ltyyy/EeveeSpotifyNext")!)
    }
}
