import Foundation

enum CuckooGeneratorError: Error {
    case ioError(any Error)
    case unknownError(any Error)
    case stderrUsed
    
    var description: String {
        switch self {
        case .ioError(let error):
            return "\(error)"
        case .unknownError(let error):
            return "\(error)"
        case .stderrUsed:
            return ""
        }
    }
}
