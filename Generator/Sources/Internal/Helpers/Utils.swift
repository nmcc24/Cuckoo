extension StringProtocol {
    /// The string without the whitespace and newlines it starts and ends with.
    var trimmed: String {
        String(trimming(where: \.isWhitespace))
    }

    /// The string without the spaces and tabs it starts and ends with; newlines stay.
    var trimmedSpaces: String {
        String(trimming { $0.isWhitespace && !$0.isNewline })
    }

    private func trimming(where isTrimmed: (Character) -> Bool) -> SubSequence {
        guard let first = firstIndex(where: { !isTrimmed($0) }), let last = lastIndex(where: { !isTrimmed($0) }) else {
            return self[endIndex...]
        }
        return self[first...last]
    }
}
