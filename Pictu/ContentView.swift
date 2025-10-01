import SwiftUI
import UniformTypeIdentifiers

// MARK: - Constants
private enum Constants {
    static let cornerRadius: CGFloat = 8
    static let padding: CGFloat = 4
    static let spacerHeight: CGFloat = 10
    static let dragOverlayOpacity: Double = 0.2
    static let iconSize: CGFloat = ImageDropConstants.dropTargetIconSize
}

struct FixedImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleNone
        imageView.image = ImageSizing.scaledImage(for: image)
        imageView.setFrameSize(ImageSizing.displaySize(for: image))
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = ImageSizing.scaledImage(for: image)
        nsView.setFrameSize(ImageSizing.displaySize(for: image))
    }
    
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isResizing = false
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            // Image or default content - anchored to top
            if let image = appState.droppedImage {
                FixedImageView(image: image)
                    .cornerRadius(Constants.cornerRadius)
                    .padding(Constants.padding)
            } else {
                // Show the same drop target as the settings Images pane
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDragOver ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        VStack(spacing: 8) {
                            SwiftUI.Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Drop an image here")
                                .foregroundColor(.secondary)
                        }
                    )
                    .padding(8)
            }
            
            // Small spacer to reduce space between image and settings
            Spacer()
                .frame(maxHeight: Constants.spacerHeight)
            
            // Settings button at bottom
            HStack {
                Spacer()
                Button {
                    // Post a settings request; AppDelegate will open the window
                    NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                } label: {
                    SwiftUI.Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Open Settings")
            }
        }
        .padding(16)
        .onDrop(of: [.image], isTargeted: $isDragOver) { providers in
            ImageDropHandler.handleDrop(providers: providers, appState: appState)
        }
        .background(
            KeyEventHandlingView { keyCode in
                if keyCode == AppDelegate.AppConstants.KeyCodes.escape {
                    // Close the popover
                    NSApp.sendAction(#selector(AppDelegate.closePopover), to: nil, from: nil)
                } else if keyCode == AppDelegate.AppConstants.KeyCodes.leftArrow {
                    appState.navigateToPreviousImage()
                } else if keyCode == AppDelegate.AppConstants.KeyCodes.rightArrow {
                    appState.navigateToNextImage()
                }
            }
        )
        .overlay(
            // Drag overlay when dragging over
            isDragOver ? 
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(Color.blue.opacity(Constants.dragOverlayOpacity))
                .overlay(
                    VStack(spacing: 8) {
                        SwiftUI.Image(systemName: "photo.badge.plus")
                            .font(.system(size: ImageDropConstants.dropTargetIconSize))
                            .foregroundColor(.blue)
                        Text("Drop image here")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                )
            : nil
        )
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") { appState.showError = false }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
    }
    
    
}

