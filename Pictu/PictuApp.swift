import SwiftUI

@main
struct PictuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(appDelegate.appState)
                .frame(width: 360, height: 220)
                .padding()
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
