extension Array where Element == String {
    /// Joins the parts of a generated file with one blank line between them, whatever newlines each part ends with,
    /// and ends the file with one newline.
    func joinedByBlankLines() -> String {
        let parts = map { part in
            var part = Substring(part)
            while part.last == "\n" { part.removeLast() }
            return part
        }
        .filter { !$0.isEmpty }
        return parts.isEmpty ? "" : parts.joined(separator: "\n\n") + "\n"
    }
}
