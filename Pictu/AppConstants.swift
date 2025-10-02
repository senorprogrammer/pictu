import Foundation
import AppKit

// MARK: - Application Constants
// Single source of truth for all application constants
enum AppConstants {
    
    // MARK: - Popover Constants
    enum Popover {
        static let borderPadding: CGFloat = 32
        static let settingsButtonHeight: CGFloat = 60
        static let minimumWidth: CGFloat = 120
        static let minimumHeight: CGFloat = 120
        static let imagePadding: CGFloat = 16
        static let defaultSize = NSSize(width: 320, height: 240)
    }
    
    // MARK: - Window Constants
    enum Window {
        static let defaultWidth: CGFloat = 500
        static let defaultHeight: CGFloat = 400
    }
    
    // MARK: - Key Codes
    enum KeyCodes {
        static let delete = 51
        static let leftArrow = 123
        static let rightArrow = 124
        static let escape = 53
    }
    
    // MARK: - Image Constants
    enum Image {
        static let maxDimension: CGFloat = 640
        static let thumbnailSize: CGFloat = 60
        static let thumbnailCornerRadius: CGFloat = 8
        static let selectionBorderWidth: CGFloat = 3
    }
    
    // MARK: - Drop Target Constants
    enum DropTarget {
        static let iconSize: CGFloat = 40
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 8
    }
    
    // MARK: - Animation Timing
    enum Animation {
        static let focusDelay: TimeInterval = 0.1
        static let deletionDelay: TimeInterval = 0.1
        static let popoverCloseDelay: TimeInterval = 0.2
        static let popoverReopenDelay: TimeInterval = 0.1
    }
    
    // MARK: - Layout Constants
    enum Layout {
        static let cornerRadius: CGFloat = 8
        static let padding: CGFloat = 4
        static let spacerHeight: CGFloat = 10
        static let dragOverlayOpacity: Double = 0.2
        static let thumbnailStripHeight: CGFloat = 72
        static let thumbnailSpacing: CGFloat = 8
        static let thumbnailPadding: CGFloat = 6
    }
    
    // MARK: - About Window Constants
    enum About {
        static let iconSize: CGFloat = 64
        static let windowWidth: CGFloat = 300
        static let windowHeight: CGFloat = 400
        static let spacing: CGFloat = 20
        static let innerSpacing: CGFloat = 12
        static let padding: CGFloat = 30
        static let horizontalPadding: CGFloat = 20
    }
}
