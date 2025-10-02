import SwiftUI
import UniformTypeIdentifiers


struct FixedImageView: NSViewRepresentable {
    let image: NSImage
    let maxDimension: CGFloat

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleNone
        imageView.image = ImageSizing.scaledImage(for: image, maxDimension: maxDimension)
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        imageView.image = ImageSizing.scaledImage(for: image, maxDimension: maxDimension)
    }
    
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            // Image or default content - anchored to top
            if let image = appState.droppedImage {
                FixedImageView(image: image, maxDimension: CGFloat(appState.maxWindowSize))
                    .cornerRadius(AppConstants.Layout.cornerRadius)
                    .padding(16)
            } else {
                // Show the same drop target as the settings Images pane
                DropTargetView(
                    isDragOver: $isDragOver,
                    onDrop: { providers in
                        ImageDropHandler.handleDrop(providers: providers, appState: appState)
                    }
                )
            }
            
        }
        .background(
            KeyEventHandlingView { keyCode in
                if keyCode == AppConstants.KeyCodes.escape {
                    // Close the popover
                    NSApp.sendAction(#selector(AppDelegate.closePopover), to: nil, from: nil)
                } else if keyCode == AppConstants.KeyCodes.leftArrow {
                    appState.navigateToPreviousImage()
                } else if keyCode == AppConstants.KeyCodes.rightArrow {
                    appState.navigateToNextImage()
                }
            }
        )
        .overlay(
            ErrorAlertView(errorManager: ErrorManager.shared)
        )
    }
    
    
}

