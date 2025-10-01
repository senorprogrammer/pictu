import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private enum Layout {
        static let iconSize: CGFloat = 64
        static let windowWidth: CGFloat = 300
        static let windowHeight: CGFloat = 400
        static let spacing: CGFloat = 20
        static let innerSpacing: CGFloat = 12
        static let padding: CGFloat = 30
        static let horizontalPadding: CGFloat = 20
    }
    
    private let authorName = "Chris Cummer"
    
    var body: some View {
        VStack(spacing: Layout.spacing) {
            // App icon and name
            VStack(spacing: Layout.innerSpacing) {
                SwiftUI.Image(systemName: "photo.on.rectangle")
                    .font(.system(size: Layout.iconSize))
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
                .padding(.horizontal, Layout.horizontalPadding)
            
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
        .padding(Layout.padding)
        .frame(width: Layout.windowWidth, height: Layout.windowHeight)
    }
}

#Preview {
    AboutView()
}
