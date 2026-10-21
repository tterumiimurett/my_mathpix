import AppKit
import SwiftUI

struct MainWindowRegistrationView: NSViewRepresentable {
    let register: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> RegistrationView {
        RegistrationView(register: register)
    }

    func updateNSView(_ nsView: RegistrationView, context: Context) {
        nsView.register = register
    }

    final class RegistrationView: NSView {
        var register: @MainActor (NSWindow) -> Void

        init(register: @escaping @MainActor (NSWindow) -> Void) {
            self.register = register
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { register(window) }
        }
    }
}
