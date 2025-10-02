import Foundation
import AppKit
import Combine

// MARK: - Thumbnail Manager
class ThumbnailManager: ObservableObject {
    @Published private var refreshTrigger = UUID()
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState) {
        self.appState = appState
        setupReactiveUpdates()
    }
    
    // MARK: - Public Methods
    
    func updateAppState(_ newAppState: AppState) {
        self.appState = newAppState
        setupReactiveUpdates()
    }
    
    // MARK: - Computed Properties
    
    /// Returns all images directly from Core Data (single source of truth)
    var images: [(fileName: String, isActive: Bool, createdAt: Date)] {
        _ = refreshTrigger // Access to trigger SwiftUI updates
        return appState.getAllImages()
    }
    
    // MARK: - Private Methods
    
    private func setupReactiveUpdates() {
        // Listen for changes to the dropped image (indicates active image changed)
        appState.$droppedImage
            .sink { [weak self] _ in
                // Trigger UI update when active image changes
                self?.refreshTrigger = UUID()
            }
            .store(in: &cancellables)
    }
    
    func deleteImage(_ fileName: String) {
        // Delete the image - AppState now handles replacement selection
        appState.deleteImage(fileName: fileName)
    }
    
}
