import SwiftUI
import AppKit

// Protocol for key event coordinators
protocol KeyEventCoordinator: AnyObject {
    func handleKeyPress(_ keyCode: UInt16)
}

// Custom NSView to handle key events
struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyPress: (UInt16) -> Void
    
    func makeCoordinator() -> Coordinator {
        print("🔍 [KeyEventHandlingView] makeCoordinator called")
        return Coordinator(onKeyPress: onKeyPress)
    }
    
    func makeNSView(context: Context) -> KeyEventNSView {
        print("🔍 [KeyEventHandlingView] makeNSView called")
        let view = KeyEventNSView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: KeyEventNSView, context: Context) {
        print("🔍 [KeyEventHandlingView] updateNSView called")
        // Update the coordinator's handler
        context.coordinator.onKeyPress = onKeyPress
    }
    
    class Coordinator: KeyEventCoordinator {
        var onKeyPress: (UInt16) -> Void
        
        init(onKeyPress: @escaping (UInt16) -> Void) {
            self.onKeyPress = onKeyPress
            print("🔍 [Coordinator] initialized")
        }
        
        func handleKeyPress(_ keyCode: UInt16) {
            print("🔍 [Coordinator] handleKeyPress called with code: \(keyCode)")
            onKeyPress(keyCode)
            print("🔍 [Coordinator] onKeyPress completed")
        }
    }
}

class KeyEventNSView: NSView {
    var coordinator: KeyEventCoordinator?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            // Make this view the first responder when it's added to a window
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }
    }
    
    // We need this for the key event handling to work
    override func becomeFirstResponder() -> Bool {
        print("🔍 [KeyEvent] Becoming first responder")
        return super.becomeFirstResponder()
    }
    
    // We need this for the key event handling to work
    override func resignFirstResponder() -> Bool {
        print("🔍 [KeyEvent] Resigning first responder")
        return super.resignFirstResponder()
    }
    
    override func keyDown(with event: NSEvent) {
        let keyName = getKeyName(for: event.keyCode)
        print("🔍 [KeyEvent] Key pressed: \(keyName) (code: \(event.keyCode))")
        print("🔍 [KeyEvent] First responder: \(window?.firstResponder == self)")
        print("🔍 [KeyEvent] coordinator exists: \(coordinator != nil)")
        if let coordinator = coordinator {
            print("🔍 [KeyEvent] About to call coordinator.handleKeyPress")
            coordinator.handleKeyPress(event.keyCode)
            print("🔍 [KeyEvent] coordinator.handleKeyPress returned")
        } else {
            print("🔍 [KeyEvent] Coordinator is nil!")
        }
    }
    
    private func getKeyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 51: return "DELETE"
        case 123: return "LEFT ARROW"
        case 124: return "RIGHT ARROW"
        case 53: return "ESCAPE"
        default: return "UNKNOWN (\(keyCode))"
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Ensure navigation keys are handled here to prevent system key equivalents
        let navigationKeys: Set<UInt16> = [
            UInt16(AppDelegate.AppConstants.KeyCodes.delete),
            UInt16(AppDelegate.AppConstants.KeyCodes.leftArrow),
            UInt16(AppDelegate.AppConstants.KeyCodes.rightArrow)
        ]
        
        if navigationKeys.contains(event.keyCode) {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}


