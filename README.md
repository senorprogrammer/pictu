# Pictu

A lightweight macOS menubar utility for viewing and managing images. Pictu provides a convenient way to keep images accessible from your menubar with drag-and-drop support and persistent storage.

<div align="center">
  <img src="resources/pictu-example.jpg" alt="Pictu App Screenshot" width="300">
</div>

## Requirements

- macOS 12.0 or later
- Xcode 14.0 or later (for building)
- Accessibility permissions (for global keyboard shortcuts)

## Installation

### Building from Source
1. Clone the repository
2. Open `Pictu.xcodeproj` in Xcode
3. Build and run the project
4. Grant accessibility permissions when prompted for keyboard shortcuts

### First Launch
1. The app will appear in your menubar with a photo icon
2. Click the icon to open the popover
3. Drop an image to get started
4. Right-click the menubar icon for additional options

## Usage

### Basic Operations
- **View Image**: Click menubar icon to show the current active image
- **Add Image**: Drag and drop an image into the popover or preferences window
- **Switch Images**: Use the thumbnail strip in preferences to select different images
- **Delete Image**: Select an image and press the delete key

### Settings
- **Open Settings**: Right-click menubar icon → Settings, or use `⌘,`
- **General Tab**: Configure pinned state and view app information
- **Images Tab**: Manage your image library with thumbnail browsing

## License

This project is for personal use. Please respect the code and don't redistribute without permission.
