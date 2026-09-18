import SwiftUI

@main
struct PictuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.showPreferences()
                }.keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}
