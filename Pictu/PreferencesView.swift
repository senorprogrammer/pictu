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
            Section("Window") {
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
    @FocusState private var isFocused: Bool
    
    private var images: [(fileName: String, isActive: Bool)] {
        _ = appState.imagesRevision
        _ = appState.droppedImage
        return appState.getAllImages()
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: AppConstants.Layout.thumbnailSpacing) {
                    ForEach(images, id: \.fileName) { imageInfo in
                        ThumbnailView(
                            fileName: imageInfo.fileName,
                            isSelected: appState.activeFileName == imageInfo.fileName,
                            onTap: {
                                appState.setActiveImage(fileName: imageInfo.fileName)
                            },
                            onFileNotFound: {
                                appState.deleteImage(fileName: imageInfo.fileName)
                            },
                            onReorder: { sourceFileName, insertAfter in
                                appState.reorderImage(
                                    moving: sourceFileName,
                                    relativeTo: imageInfo.fileName,
                                    insertAfter: insertAfter
                                )
                            }
                        )
                        .id(imageInfo.fileName)
                    }
                }
                .padding(.horizontal, AppConstants.Layout.thumbnailSpacing)
                .padding(.vertical, AppConstants.Layout.thumbnailPadding)
            }
            .onChange(of: appState.activeFileName) { _, fileName in
                guard let fileName else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(fileName, anchor: .center)
                }
            }
        }
        .frame(height: AppConstants.Layout.thumbnailStripHeight)
        .background(Color.gray.opacity(0.1))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.focusDelay) {
                isFocused = true
            }
        }
        .background(
            KeyEventHandlingView { keyCode in
                if keyCode == AppConstants.KeyCodes.delete {
                    if let fileName = appState.activeFileName {
                        appState.deleteImage(fileName: fileName)
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
    let isSelected: Bool
    let onTap: () -> Void
    let onFileNotFound: () -> Void
    let onReorder: (_ sourceFileName: String, _ insertAfter: Bool) -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @State private var isFileMissing = false
    @State private var isDropTargeted = false
    
    var body: some View {
        // Don't render anything if file is missing
        if isFileMissing {
            EmptyView()
        } else {
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
                
                if isSelected || isDropTargeted {
                    RoundedRectangle(cornerRadius: AppConstants.Image.thumbnailCornerRadius)
                        .stroke(Color.accentColor, lineWidth: AppConstants.Image.selectionBorderWidth)
                        .frame(width: AppConstants.Image.thumbnailSize, height: AppConstants.Image.thumbnailSize)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onDrag {
                NSItemProvider(object: fileName as NSString)
            }
            .onDrop(of: [.utf8PlainText], isTargeted: $isDropTargeted) { providers, location in
                handleReorderDrop(providers: providers, location: location)
            }
            .help("Image: \(fileName)")
            .onAppear {
                loadThumbnail()
            }
        }
    }
    
    private func handleReorderDrop(providers: [NSItemProvider], location: CGPoint) -> Bool {
        guard let provider = providers.first else { return false }
        let insertAfter = location.x >= AppConstants.Image.thumbnailSize / 2
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let sourceFileName = object as? String else { return }
            DispatchQueue.main.async {
                self.onReorder(sourceFileName, insertAfter)
            }
        }
        return true
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

 
