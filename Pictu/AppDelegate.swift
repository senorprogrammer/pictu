import Cocoa
import SwiftUI
import ApplicationServices
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    // MARK: - Constants
    enum AppConstants {
        enum Popover {
            static let borderPadding: CGFloat = 32
            static let settingsButtonHeight: CGFloat = 60
            static let minimumWidth: CGFloat = 120
            static let minimumHeight: CGFloat = 120
            static let imagePadding: CGFloat = 16
            static let defaultSize = NSSize(width: 320, height: 240)
        }
        
        enum Window {
            static let defaultWidth: CGFloat = 500
            static let defaultHeight: CGFloat = 400
        }
        
        enum KeyCodes {
            static let delete = 51
            static let leftArrow = 123
            static let rightArrow = 124
            static let escape = 53
        }
    }
    
    // MARK: - Properties
    var statusItem: NSStatusItem?
    let popover = NSPopover()

    // App state shared with SwiftUI views
    let appState = AppState()

    // Preferences window controller
    private var prefsWC: NSWindowController?
    
    // About window controller
    private var aboutWC: NSWindowController?

    // Keyboard shortcut manager
    private var keyboardShortcutManager: KeyboardShortcutManager!
    
    // Keep Combine cancellables alive
    private var cancellables: Set<AnyCancellable> = []

    // Main menu (left-click)
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(withTitle: "About Pictu", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }()
    
    // Right-click menu (for future use)
    private lazy var rightClickMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1) Menubar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle",
                                   accessibilityDescription: "Menu")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 2) Popover + SwiftUI content
        let contentView = ContentView()
            .environmentObject(appState)

        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.behavior = .transient
        
        // Set initial size based on whether there's an image
        if appState.droppedImage != nil {
            // Will be resized by the image change handler
        } else {
            resizePopoverForNoImage()
        }

        // 3) React to pin changes
        appState.$isPinned.sink { [weak self] pinned in
            guard let self = self else { return }
            self.popover.behavior = pinned ? .applicationDefined : .transient
        }.store(in: &cancellables)
        
        // 4) React to image changes and auto-size popover
        appState.$droppedImage.sink { [weak self] image in
            guard let self = self else { return }
            if let image = image {
                self.resizePopoverForImage(image)
            } else {
                self.resizePopoverForNoImage()
            }
        }.store(in: &cancellables)

        // 5) Keyboard shortcuts
        keyboardShortcutManager = KeyboardShortcutManager(appDelegate: self)
        keyboardShortcutManager.registerToggleShortcut()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent, let button = statusItem?.button else { return }
        
        // Check for modifier keys (Control, Option, Command, Shift)
        let hasModifiers = event.modifierFlags.intersection([.control, .option, .command, .shift]) != []
        
        if event.type == .rightMouseUp || hasModifiers {
            // Right-click or any modifier key shows the About/Quit menu
            statusItem?.menu = statusMenu
            button.performClick(nil)
            statusItem?.menu = nil
            return
        }
        
        // Regular left-click shows the main image window (popover)
        togglePopover(nil)
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    @objc func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    // MARK: - Settings / Quit

    @objc func openSettings() { showPreferences() }

    func showPreferences() {
        if prefsWC == nil {
            let root = PreferencesView().environmentObject(appState)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Pictu Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.delegate = self // Set delegate for window events
            
            // Set a reasonable default size
            window.setContentSize(NSSize(width: AppConstants.Window.defaultWidth, height: AppConstants.Window.defaultHeight))
            
            // Load saved window position
            if let savedFrame = loadWindowFrame() {
                window.setFrame(savedFrame, display: false)
            } else {
                window.center()
            }
            
            prefsWC = NSWindowController(window: window)
        }
        prefsWC?.showWindow(nil)
        prefsWC?.window?.makeKey()
        prefsWC?.window?.makeFirstResponder(prefsWC?.window?.contentViewController?.view)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        if aboutWC == nil {
            let root = AboutView()
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "About Pictu"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            
            // Center the window on the main screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowSize = window.frame.size
                let centerX = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
                let centerY = screenFrame.origin.y + (screenFrame.height - windowSize.height) / 2
                window.setFrameOrigin(NSPoint(x: centerX, y: centerY))
            } else {
                window.center()
            }
            
            aboutWC = NSWindowController(window: window)
        }
        aboutWC?.showWindow(nil)
        aboutWC?.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // Exposes whether preferences window is key without leaking private window controller
    func isPreferencesWindowKey() -> Bool {
        return prefsWC?.window?.isKeyWindow == true
    }


    private func resizePopover(to size: NSSize) {
        // Update the hosting controller's preferred size
        popover.contentViewController?.preferredContentSize = size
        
        // If popover is currently shown, close and reopen to apply new size
        // If popover is closed, just update the size for when it's next opened
        if popover.isShown {
            popover.performClose(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + ImageDropConstants.popoverReopenDelay) {
                self.reopenPopover()
            }
        }
    }
    
    private func reopenPopover() {
        guard let button = statusItem?.button else { return }
        
        // Force a fresh positioning calculation by ensuring the popover is fully closed
        if popover.isShown {
            popover.performClose(nil)
        }
        
        // Small delay to ensure the popover is fully closed before reopening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            // Force the popover to recalculate its position by temporarily changing the content size
            // This prevents NSPopover from reusing the previous position when only height changes
            let currentSize = self.popover.contentViewController?.preferredContentSize ?? NSSize(width: 320, height: 240)
            self.popover.contentViewController?.preferredContentSize = NSSize(width: currentSize.width + 1, height: currentSize.height)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                // Restore the correct size
                self.popover.contentViewController?.preferredContentSize = currentSize
                
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
                self.popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    private func resizePopoverForImage(_ image: NSImage) {
        // Calculate popover size: scaled image size + padding on all sides
        let scaledImageSize = ImageSizing.displaySize(for: image)
        let newWindowSize = NSSize(
            width: scaledImageSize.width + (AppConstants.Popover.imagePadding * 2),
            height: scaledImageSize.height + (AppConstants.Popover.imagePadding * 2)
        )
        
        resizePopover(to: newWindowSize)
    }
    
    private func resizePopoverForNoImage() {
        resizePopover(to: AppConstants.Popover.defaultSize)
    }

    deinit {
        keyboardShortcutManager?.unregisterShortcuts()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == prefsWC?.window else { return }
        saveWindowFrame(window)
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == prefsWC?.window else { return }
        saveWindowFrame(window)
    }
    
    // MARK: - Helper Methods
    
    private func loadWindowFrame() -> NSRect? {
        let settings = PersistenceManager.shared.loadAppSettings()
        return settings.windowFrame
    }
    
    private func saveWindowFrame(_ window: NSWindow) {
        PersistenceManager.shared.saveAppSettings(
            isPinned: appState.isPinned,
            windowFrame: window.frame
        )
    }
}

