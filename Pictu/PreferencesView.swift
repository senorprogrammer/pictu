import SwiftUI
import UniformTypeIdentifiers

// MARK: - Error Types
enum ThumbnailError: LocalizedError {
    case imageLoadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let fileName):
            return "Failed to load thumbnail for \(fileName)"
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: PreferencesTab = .general

    enum PreferencesTab: String, CaseIterable {
        case general = "General"
        case images = "Images"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .images: return "photo"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                ForEach(PreferencesTab.allCases, id: \.self) { tab in
                    HStack {
                        SwiftUI.Image(systemName: tab.icon)
                            .frame(width: 16)
                        Text(tab.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear
                    )
                    .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTab = tab
                    }
                }
                
                Spacer()
            }
            .frame(width: 160)
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color(NSColor.separatorColor), width: 0.5)
            
            // Main content
            VStack {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .images:
                    ImageDropView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadSelectedTab()
        }
        .onChange(of: selectedTab) {
            saveSelectedTab(selectedTab)
        }
    }
    
    private func loadSelectedTab() {
        if let savedTabName = PersistenceManager.shared.loadSelectedPreferencesTab(),
           let savedTab = PreferencesTab(rawValue: savedTabName) {
            selectedTab = savedTab
        }
    }
    
    private func saveSelectedTab(_ tab: PreferencesTab) {
        PersistenceManager.shared.saveSelectedPreferencesTab(tab.rawValue)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Keep popover pinned by default", isOn: Binding(
                    get: { appState.isPinned },
                    set: { appState.savePinnedState($0) }
                ))
            }

            Section("Appearance") {
                Label("Icon: photo.on.rectangle", systemImage: "photo.on.rectangle")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ImageDropView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area - takes up available space
            VStack(spacing: 0) {
                if let image = appState.droppedImage {
                    SwiftUI.Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fill the available space with 8px border, excluding thumbnail area
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
            }
            .onDrop(of: [.image], isTargeted: $isDragOver) { providers in
                ImageDropHandler.handleDrop(providers: providers, appState: appState)
            }
            
            // Spacer to push thumbnail strip to bottom
            Spacer()
            
            // Thumbnail strip fixed at bottom
            ThumbnailStrip()
        }
    }
    
}

struct ThumbnailStrip: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var thumbnailManager: ThumbnailManager
    @FocusState private var isFocused: Bool
    
    init() {
        // Create a placeholder that will be properly initialized in onAppear
        self._thumbnailManager = StateObject(wrappedValue: ThumbnailManager(appState: AppState()))
    }
    
    private func initializeThumbnailManager() {
        // Update the existing manager's appState reference
        thumbnailManager.updateAppState(appState)
        // Reload images with the correct appState
        thumbnailManager.loadImages()
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: ImageDropConstants.thumbnailSpacing) {
                    ForEach(thumbnailManager.images.indices, id: \.self) { idx in
                        let imageInfo = thumbnailManager.images[idx]
                        let isSelected = (thumbnailManager.selectedIndex == idx)
                        
                        ThumbnailView(
                            fileName: imageInfo.fileName,
                            isActive: imageInfo.isActive,
                            isSelected: isSelected,
                            onTap: {
                                thumbnailManager.selectImage(idx)
                            },
                            onFileNotFound: {
                                thumbnailManager.deleteImage(imageInfo.fileName)
                            }
                        )
                        .id(imageInfo.fileName) // Use fileName as unique identifier
                    }
                }
                .padding(.horizontal, ImageDropConstants.thumbnailSpacing)
                .padding(.vertical, ImageDropConstants.thumbnailPadding)
            }
            .onChange(of: thumbnailManager.selectedIndex) {
                if let newIndex = thumbnailManager.selectedIndex, newIndex < thumbnailManager.images.count {
                    let fileName = thumbnailManager.images[newIndex].fileName
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(fileName, anchor: .center)
                    }
                }
            }
        }
        .frame(height: ImageDropConstants.thumbnailStripHeight)
        .background(Color.gray.opacity(0.1))
        .onAppear {
            initializeThumbnailManager()
            // Auto-focus when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + ImageDropConstants.focusDelay) {
                isFocused = true
            }
        }
        .onChange(of: appState.droppedImage) {
            thumbnailManager.loadImages()
        }
        .background(
            KeyEventHandlingView { keyCode in
                if keyCode == AppDelegate.AppConstants.KeyCodes.delete {
                    if let selectedIndex = thumbnailManager.selectedIndex, selectedIndex < thumbnailManager.images.count {
                        let fileName = thumbnailManager.images[selectedIndex].fileName
                        thumbnailManager.deleteImage(fileName)
                    }
                } else if keyCode == AppDelegate.AppConstants.KeyCodes.leftArrow {
                    thumbnailManager.navigateLeft()
                } else if keyCode == AppDelegate.AppConstants.KeyCodes.rightArrow {
                    thumbnailManager.navigateRight()
                }
            }
        )
        .focused($isFocused)
    }
    
}

struct ThumbnailView: View {
    let fileName: String
    let isActive: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onFileNotFound: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @State private var isFileMissing = false
    
    var body: some View {
        // Don't render anything if file is missing
        if isFileMissing {
            EmptyView()
        } else {
            Button(action: onTap) {
                ZStack {
                    if let thumbnail = thumbnail {
                        SwiftUI.Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: ImageDropConstants.thumbnailSize, height: ImageDropConstants.thumbnailSize)
                            .clipShape(RoundedRectangle(cornerRadius: ImageDropConstants.thumbnailCornerRadius))
                    } else if isLoading {
                        RoundedRectangle(cornerRadius: ImageDropConstants.thumbnailCornerRadius)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: ImageDropConstants.thumbnailSize, height: ImageDropConstants.thumbnailSize)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: ImageDropConstants.thumbnailCornerRadius)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: ImageDropConstants.thumbnailSize, height: ImageDropConstants.thumbnailSize)
                            .overlay(
                                SwiftUI.Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                    
                    // Selection indicator
                    if isSelected {
                        RoundedRectangle(cornerRadius: ImageDropConstants.thumbnailCornerRadius)
                            .stroke(Color.accentColor, lineWidth: ImageDropConstants.selectionBorderWidth)
                            .frame(width: ImageDropConstants.thumbnailSize, height: ImageDropConstants.thumbnailSize)
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle()) // better hit-testing
            .help("Image: \(fileName)")
            .onAppear {
                loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() {
        guard let fileURL = FileManager.pictuImageURL(for: fileName) else {
            print("❌ Invalid file name: \(fileName)")
            isFileMissing = true
            onFileNotFound()
            return
        }
        
        do {
            if FileManager.pictuImageExists(fileName: fileName) {
                guard let loadedImage = NSImage(contentsOf: fileURL) else {
                    throw ThumbnailError.imageLoadFailed(fileName)
                }
                thumbnail = loadedImage
            } else {
                isFileMissing = true
                onFileNotFound()
            }
        } catch {
            print("❌ Failed to load thumbnail for \(fileName): \(error)")
            isFileMissing = true
            onFileNotFound()
        }
        isLoading = false
    }
}

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
