import SwiftUI
import AppKit

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
        context.coordinator.onKeyPress = onKeyPress
    }
    
    class Coordinator {
        var onKeyPress: (UInt16) -> Void
        
        init(onKeyPress: @escaping (UInt16) -> Void) {
            self.onKeyPress = onKeyPress
        }
    }
}

class KeyEventNSView: NSView {
    var coordinator: KeyEventHandlingView.Coordinator?
    
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
        coordinator?.onKeyPress(event.keyCode)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Ensure navigation keys are handled here to prevent system key equivalents
        let navigationKeys: Set<UInt16> = [
            UInt16(AppConstants.KeyCodes.delete),
            UInt16(AppConstants.KeyCodes.leftArrow),
            UInt16(AppConstants.KeyCodes.rightArrow)
        ]
        
        if navigationKeys.contains(event.keyCode) {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}


