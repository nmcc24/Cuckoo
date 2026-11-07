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
