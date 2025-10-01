import SwiftUI
import AppKit

// Custom NSView to handle key events
struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyPress: (UInt16) -> Void
    
    func makeNSView(context: Context) -> KeyEventNSView {
        let view = KeyEventNSView()
        view.onKeyPress = onKeyPress
        return view
    }
    
    func updateNSView(_ nsView: KeyEventNSView, context: Context) {
        nsView.onKeyPress = onKeyPress
    }
}

class KeyEventNSView: NSView {
    var onKeyPress: ((UInt16) -> Void)?
    
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
        onKeyPress?(event.keyCode)
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


