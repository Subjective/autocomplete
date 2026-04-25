import Foundation

extension String {
    func substringByUTF16Range(location: Int, length: Int) -> String? {
        guard location >= 0, length >= 0, location + length <= utf16.count else {
            return nil
        }

        let utf16Start = utf16.index(utf16.startIndex, offsetBy: location)
        let utf16End = utf16.index(utf16Start, offsetBy: length)

        guard
            let start = String.Index(utf16Start, within: self),
            let end = String.Index(utf16End, within: self)
        else {
            return nil
        }

        return String(self[start..<end])
    }

    func replacingUTF16Range(location: Int, length: Int, with replacement: String) -> String? {
        guard location >= 0, length >= 0, location + length <= utf16.count else {
            return nil
        }

        let utf16Start = utf16.index(utf16.startIndex, offsetBy: location)
        let utf16End = utf16.index(utf16Start, offsetBy: length)

        guard
            let start = String.Index(utf16Start, within: self),
            let end = String.Index(utf16End, within: self)
        else {
            return nil
        }

        var copy = self
        copy.replaceSubrange(start..<end, with: replacement)
        return copy
    }
}
