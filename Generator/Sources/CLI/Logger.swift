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
        case error
    }

    /// The lowest level that's printed. `GenerateCommand` binds it for the whole run, and the tasks that generate
    /// files concurrently inherit it.
    @TaskLocal static var level: LogLevel = .info
}

func log(_ level: Logger.LogLevel, message: Any...) {
    if level >= Logger.level {
        print(message.map(String.init(describing:)).joined(separator: " "))
    }
}

/// Writes `text` to standard error. `FileHandle` would link swift-corelibs Foundation, and with it ICU's data, into
/// the generator on Linux; the file descriptor needs only the C library.
func printToStandardError(_ text: String) {
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
