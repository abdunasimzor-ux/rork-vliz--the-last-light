//
//  VLIZTheLastLightApp.swift
//  VLIZTheLastLight
//
//  Created by Rork on October 24, 2026.
//

import SwiftUI

@main
struct VLIZTheLastLightApp: App {
    init() {
        AudioManager.shared.start(settings: ProgressionManager.shared.settings)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .preferredColorScheme(.dark)
        }
    }
}
