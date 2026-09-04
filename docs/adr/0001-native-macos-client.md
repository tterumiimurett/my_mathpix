# Build the client as a native macOS application

The product will use Swift and SwiftUI, with AppKit where macOS-specific integration requires it. A native client is preferred over Electron, Tauri, or packaged Python because Screen Capture, global shortcuts, the clipboard, Keychain, menu-bar behavior, and App Store distribution are central to the product and would otherwise depend on an additional cross-platform integration layer.
