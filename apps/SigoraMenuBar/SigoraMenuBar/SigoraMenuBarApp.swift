import SwiftUI

@main
struct SigoraMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("Sigora", systemImage: "lock.shield") {
            RuntimePanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
