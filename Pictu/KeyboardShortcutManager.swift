import Cocoa
import ApplicationServices

class KeyboardShortcutManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
    
    deinit {
        unregisterShortcuts()
    }
    
    func registerToggleShortcut() {
        // Check accessibility permissions
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ Accessibility permissions not granted. Global shortcuts may not work.")
            print("Please grant accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility")
        }
        
        // Original shortcut: ⌥⌘P
        let originalMods: NSEvent.ModifierFlags = [.option, .command]
        let originalKey = "p"
        
        // New shortcut: ⌃⌥⌘0
        let newMods: NSEvent.ModifierFlags = [.control, .option, .command]
        let newKey = "0"

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleShortcut(event: event, requiredMods: originalMods, key: originalKey) == true {
                return
            }
            if self?.handleShortcut(event: event, requiredMods: newMods, key: newKey) == true {
                return
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Don't intercept navigation keys when preferences window is key
            // Only intercept when popover is shown or when it's not a preferences window
            let isPreferencesWindow = self.appDelegate?.isPreferencesWindowKey() == true
            
            if isPreferencesWindow {
                // Let preferences window handle all keys
                return event
            }
            
            // For popover, don't intercept navigation keys
            if event.keyCode == AppConstants.KeyCodes.delete ||
               event.keyCode == AppConstants.KeyCodes.leftArrow ||
               event.keyCode == AppConstants.KeyCodes.rightArrow ||
               event.keyCode == AppConstants.KeyCodes.escape {
                return event
            }
            
            if self.handleShortcut(event: event, requiredMods: originalMods, key: originalKey) == true {
                return nil
            }
            if self.handleShortcut(event: event, requiredMods: newMods, key: newKey) == true {
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
    private func handleShortcut(event: NSEvent,
                                requiredMods: NSEvent.ModifierFlags,
                                key: String) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if mods == requiredMods, event.charactersIgnoringModifiers?.lowercased() == key {
            // Ensure app is activated when shortcut is triggered
            NSApp.activate(ignoringOtherApps: true)
            appDelegate?.togglePopover(nil)
            return true
        }
        return false
    }
}
