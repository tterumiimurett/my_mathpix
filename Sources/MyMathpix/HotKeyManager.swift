import Carbon.HIToolbox
import Foundation

struct HotKeyConfiguration: Codable, Equatable {
    var key = "M"
    var command = true
    var control = true
    var option = false
    var shift = false

    var displayName: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        parts.append(key.uppercased())
        return parts.joined()
    }
}

@MainActor
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return noErr }
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard status == noErr, id.id == 1 else { return status }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in manager.action?() }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandlerRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    func register(_ configuration: HotKeyConfiguration, action: @escaping () -> Void) throws {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        guard let keyCode = Self.keyCode(for: configuration.key) else {
            throw AppError.service("The shortcut key must be a letter from A to Z.")
        }
        var modifiers: UInt32 = 0
        if configuration.command { modifiers |= UInt32(cmdKey) }
        if configuration.control { modifiers |= UInt32(controlKey) }
        if configuration.option { modifiers |= UInt32(optionKey) }
        if configuration.shift { modifiers |= UInt32(shiftKey) }
        guard modifiers != 0 else {
            throw AppError.service("The shortcut needs at least one modifier key.")
        }
        let signature = OSType(0x4D4D5058) // MMPX
        let id = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode), modifiers, id,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard status == noErr else {
            throw AppError.service("The shortcut could not be registered. It may conflict with another app.")
        }
        self.action = action
    }

    private static func keyCode(for key: String) -> Int? {
        let values: [Character: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z
        ]
        guard let character = key.uppercased().first else { return nil }
        return values[character]
    }
}
