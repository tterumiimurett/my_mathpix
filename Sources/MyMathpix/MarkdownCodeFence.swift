import Foundation

struct MarkdownCodeFence: Equatable {
    let character: Character
    let length: Int

    static func opening(in line: String) -> Self? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let length = trimmed.prefix { $0 == first }.count
        return length >= 3 ? Self(character: first, length: length) : nil
    }

    func closes(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == character else { return false }
        let closingLength = trimmed.prefix { $0 == character }.count
        return closingLength >= length
            && trimmed.dropFirst(closingLength).trimmingCharacters(in: .whitespaces).isEmpty
    }
}
