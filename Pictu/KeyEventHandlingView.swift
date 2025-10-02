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
        return Coordinator(onKeyPress: onKeyPress)
    }
    
    func makeNSView(context: Context) -> KeyEventNSView {
        let view = KeyEventNSView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: KeyEventNSView, context: Context) {
        // Update the coordinator's handler
        context.coordinator.onKeyPress = onKeyPress
    }
    
    class Coordinator: KeyEventCoordinator {
        var onKeyPress: (UInt16) -> Void
        
        init(onKeyPress: @escaping (UInt16) -> Void) {
            self.onKeyPress = onKeyPress
        }
        
        func handleKeyPress(_ keyCode: UInt16) {
            onKeyPress(keyCode)
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
        return super.becomeFirstResponder()
    }
    
    // We need this for the key event handling to work
    override func resignFirstResponder() -> Bool {
        return super.resignFirstResponder()
    }
    
    override func keyDown(with event: NSEvent) {
        coordinator?.handleKeyPress(event.keyCode)
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


