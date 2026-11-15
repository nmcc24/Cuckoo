#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
import Darwin
#endif

enum Logger {
    enum LogLevel: Comparable, Sendable {
        case verbose
        case info
    }

    /// The lowest level that's printed. `GenerateCommand` binds it for the whole run, and the tasks that generate
    /// files concurrently inherit it.
    @TaskLocal static var level: LogLevel = .info

    /// Where the messages go instead of standard output and standard error, so tests can read them. `nil` prints
    /// them.
    @TaskLocal static var capture: (@Sendable (String) -> Void)?
}

func log(_ level: Logger.LogLevel, message: Any...) {
    guard level >= Logger.level else { return }
    let text = message.map(String.init(describing:)).joined(separator: " ")
    if let capture = Logger.capture {
        capture(text + "\n")
    } else {
        print(text)
    }
}

/// Writes `text` to standard error. `FileHandle` would link swift-corelibs Foundation, and with it ICU's data, into
/// the generator on Linux; the file descriptor needs only the C library.
func printToStandardError(_ text: String) {
    if let capture = Logger.capture {
        capture(text)
        return
    }
    var text = text
    text.withUTF8 { bytes in
        var offset = 0
        while offset < bytes.count, let start = bytes.baseAddress {
            let written = write(2, start + offset, bytes.count - offset)
            guard written > 0 else { return }
            offset += written
        }
    }
}
