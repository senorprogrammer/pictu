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
        .onChange(of: selectedTab) { _, newValue in
            saveSelectedTab(newValue)
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
    
    private let maxWindowSizeOptions: [Int32] = [320, 640, 1024]
    
    var body: some View {
        Form {
            Section("Popover") {
                Toggle("Keep popover pinned by default", isOn: Binding(
                    get: { appState.isPinned },
                    set: { appState.savePinnedState($0) }
                ))
                
                Picker("Maximum popover size", selection: Binding(
                    get: { appState.maxWindowSize },
                    set: { appState.saveMaxWindowSize($0) }
                )) {
                    ForEach(maxWindowSizeOptions, id: \.self) { size in
                        Text(String(size)).tag(size)
                    }
                }
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
                    // Show current image with drop handling overlaid
                    SwiftUI.Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            // Invisible drop overlay when image exists
                            Color.clear
                                .contentShape(Rectangle())
                                .onDrop(of: [.image], isTargeted: $isDragOver) { providers in
                                    ImageDropHandler.handleDrop(providers: providers, appState: appState)
                                }
                        )
                        .overlay(
                            // Show drag indicator when dragging over image
                            isDragOver ? 
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                                    .fill(Color.blue.opacity(0.1))
                                    .padding(16)
                                : nil
                        )
                } else {
                    // Show drop target when no image
                    DropTargetView(
                        isDragOver: $isDragOver,
                        onDrop: { providers in
                            ImageDropHandler.handleDrop(providers: providers, appState: appState)
                        }
                    )
                }
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
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: AppConstants.Layout.thumbnailSpacing) {
                    ForEach(thumbnailManager.images.indices, id: \.self) { idx in
                        let imageInfo = thumbnailManager.images[idx]
                        let isSelected = (appState.currentImageIndex == idx)
                        
                        ThumbnailView(
                            fileName: imageInfo.fileName,
                            isActive: imageInfo.isActive,
                            isSelected: isSelected,
                            onTap: {
                                appState.currentImageIndex = idx
                                appState.setActiveImage(fileName: imageInfo.fileName)
                            },
                            onFileNotFound: {
                                thumbnailManager.deleteImage(imageInfo.fileName)
                            }
                        )
                        .id(imageInfo.fileName) // Use fileName as unique identifier
                    }
                }
                .padding(.horizontal, AppConstants.Layout.thumbnailSpacing)
                .padding(.vertical, AppConstants.Layout.thumbnailPadding)
            }
            .onChange(of: appState.currentImageIndex) { _, newIndex in
                if newIndex < thumbnailManager.images.count {
                    let fileName = thumbnailManager.images[newIndex].fileName
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(fileName, anchor: .center)
                    }
                }
            }
        }
        .frame(height: AppConstants.Layout.thumbnailStripHeight)
        .background(Color.gray.opacity(0.1))
        .onAppear {
            initializeThumbnailManager()
            // Auto-focus when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.focusDelay) {
                isFocused = true
            }
        }
        .onChange(of: appState.droppedImage) { _, _ in
            // Images are now automatically updated through reactive updates
        }
        .background(
            KeyEventHandlingView { keyCode in
                if keyCode == AppConstants.KeyCodes.delete {
                    let currentIndex = appState.currentImageIndex
                    if currentIndex < thumbnailManager.images.count {
                        let fileName = thumbnailManager.images[currentIndex].fileName
                        thumbnailManager.deleteImage(fileName)
                    }
                } else if keyCode == AppConstants.KeyCodes.leftArrow {
                    appState.navigateToPreviousImage()
                } else if keyCode == AppConstants.KeyCodes.rightArrow {
                    appState.navigateToNextImage()
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
                            .frame(width: AppConstants.Image.thumbnailSize, height: AppConstants.Image.thumbnailSize)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Image.thumbnailCornerRadius))
                    } else if isLoading {
                        RoundedRectangle(cornerRadius: AppConstants.Image.thumbnailCornerRadius)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: AppConstants.Image.thumbnailSize, height: AppConstants.Image.thumbnailSize)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: AppConstants.Image.thumbnailCornerRadius)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: AppConstants.Image.thumbnailSize, height: AppConstants.Image.thumbnailSize)
                            .overlay(
                                SwiftUI.Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                    
                    // Selection indicator
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppConstants.Image.thumbnailCornerRadius)
                            .stroke(Color.accentColor, lineWidth: AppConstants.Image.selectionBorderWidth)
                            .frame(width: AppConstants.Image.thumbnailSize, height: AppConstants.Image.thumbnailSize)
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
            ErrorManager.shared.logError(NSError(domain: "ThumbnailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file name: \(fileName)"]), context: "loading thumbnail")
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
            ErrorManager.shared.logError(error, context: "loading thumbnail for \(fileName)")
            isFileMissing = true
            onFileNotFound()
        }
        isLoading = false
    }
}

 
