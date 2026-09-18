import Foundation
import SwiftUI
import Combine

class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var message: String?
    
    private init() {}
    
    /// Present an error with a custom message
    func presentError(message: String) {
        DispatchQueue.main.async {
            self.message = message
        }
    }
    
    func dismissError() {
        message = nil
    }
    
    /// Log an error without presenting it to the user
    func logError(_ error: Error, context: String = "") {
        let prefix = context.isEmpty ? "❌ Error" : "❌ Error in \(context)"
        print("\(prefix): \(error.localizedDescription)")
    }
}

struct ErrorAlertView: View {
    @ObservedObject var errorManager: ErrorManager
    
    var body: some View {
        EmptyView()
            .alert("Error", isPresented: Binding(
                get: { errorManager.message != nil },
                set: { if !$0 { errorManager.dismissError() } }
            )) {
                Button("OK") {
                    errorManager.dismissError()
                }
            } message: {
                Text(errorManager.message ?? "")
            }
    }
}
