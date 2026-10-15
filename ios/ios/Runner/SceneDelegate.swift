import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        let rootView = MoneAppView()
        window.rootViewController = UIHostingController(rootView: rootView)
        self.window = window
        window.makeKeyAndVisible()

        // Handle cold-start deep link URL if launched via Shortcut or URL scheme
        if let url = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                MoneRouteManager.shared.handle(url: url)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            MoneRouteManager.shared.handle(url: url)
        }
    }
}
