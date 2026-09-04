import Foundation

extension NSLock {
    func withLock<T>(_ action: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try action()
    }
}
