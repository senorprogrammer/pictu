import Foundation
import SwiftUI
import Combine

// MARK: - Error Types
enum PictuError: LocalizedError {
    case imageLoadFailed(String)
    case imageSaveFailed(String)
    case fileSystemError(String)
    case coreDataError(String)
    case unsupportedFileType(String)
    case directoryCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let details):
            return "Failed to load image: \(details)"
        case .imageSaveFailed(let details):
            return "Failed to save image: \(details)"
        case .fileSystemError(let details):
            return "File system error: \(details)"
        case .coreDataError(let details):
            return "Database error: \(details)"
        case .unsupportedFileType(let details):
            return "Unsupported file type: \(details)"
        case .directoryCreationFailed(let details):
            return "Failed to create directory: \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .imageLoadFailed:
            return "Please try with a different image file."
        case .imageSaveFailed:
            return "Please check available disk space and try again."
        case .fileSystemError:
            return "Please check file permissions and try again."
        case .coreDataError:
            return "Please restart the application and try again."
        case .unsupportedFileType:
            return "Please use a supported image format (PNG, JPEG, etc.)."
        case .directoryCreationFailed:
            return "Please check application permissions and try again."
        }
    }
}

// MARK: - Error Manager
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: PictuError?
    @Published var showError: Bool = false
    
    private init() {
        // Initialize the ObservableObject
    }
    
    // MARK: - Public Methods
    
    /// Present an error to the user
    /// - Parameter error: The error to present
    func presentError(_ error: PictuError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showError = true
        }
    }
    
    /// Present an error with a custom message
    /// - Parameter message: The error message
    func presentError(message: String) {
        let error = PictuError.fileSystemError(message)
        presentError(error)
    }
    
    /// Dismiss the current error
    func dismissError() {
        currentError = nil
        showError = false
    }
    
    /// Log an error without presenting it to the user
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context about where the error occurred
    func logError(_ error: Error, context: String = "") {
        let prefix = context.isEmpty ? "Error" : "Error in \(context)"
        print("\(prefix): \(error.localizedDescription)")
        
        // Log to console with emoji for better visibility
        if let pictuError = error as? PictuError {
            print("❌ \(pictuError.errorDescription ?? "Unknown error")")
        } else {
            print("❌ \(error.localizedDescription)")
        }
    }
}

// MARK: - Error Alert View
struct ErrorAlertView: View {
    @ObservedObject var errorManager: ErrorManager
    
    var body: some View {
        EmptyView()
            .alert("Error", isPresented: $errorManager.showError) {
                Button("OK") {
                    errorManager.dismissError()
                }
            } message: {
                if let error = errorManager.currentError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.errorDescription ?? "Unknown error")
                        
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
    }
}
