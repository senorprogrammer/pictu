import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    
    private let authorName = "Chris Cummer"
    
    var body: some View {
        VStack(spacing: AppConstants.About.spacing) {
            // App icon and name
            VStack(spacing: AppConstants.About.innerSpacing) {
                SwiftUI.Image(systemName: "photo.on.rectangle")
                    .font(.system(size: AppConstants.About.iconSize))
                    .foregroundColor(.accentColor)
                
                Text("Pictu")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text("A simple menubar image viewer for macOS")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, AppConstants.About.horizontalPadding)
            
            // Copyright
            Text("© \(String(Calendar.current.component(.year, from: Date()))) \(authorName). All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Close button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(AppConstants.About.padding)
        .frame(width: AppConstants.About.windowWidth, height: AppConstants.About.windowHeight)
    }
}

#Preview {
    AboutView()
}
