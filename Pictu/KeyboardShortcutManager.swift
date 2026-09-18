import Cocoa
import ApplicationServices

class KeyboardShortcutManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var appDelegate: AppDelegate?
    
    private let toggleModifiers: NSEvent.ModifierFlags = [.option, .command]
    private let toggleKey = "p"
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
    
    deinit {
        unregisterShortcuts()
    }
    
    func registerToggleShortcut() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ Accessibility permissions not granted. Global shortcuts may not work.")
            print("Please grant accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility")
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleShortcut(event: event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if self.appDelegate?.isPreferencesWindowKey() == true {
                return event
            }
            
            if event.keyCode == AppConstants.KeyCodes.delete ||
               event.keyCode == AppConstants.KeyCodes.leftArrow ||
               event.keyCode == AppConstants.KeyCodes.rightArrow ||
               event.keyCode == AppConstants.KeyCodes.escape {
                return event
            }
            
            if self.handleShortcut(event: event) {
                return nil
            }
            return event
        }
    }
    
    func unregisterShortcuts() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
    
    @discardableResult
    private func handleShortcut(event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard mods == toggleModifiers, event.charactersIgnoringModifiers?.lowercased() == toggleKey else {
            return false
        }
        NSApp.activate(ignoringOtherApps: true)
        appDelegate?.togglePopover(nil)
        return true
    }
}
