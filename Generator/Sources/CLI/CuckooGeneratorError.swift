import Foundation

enum CuckooGeneratorError: Error {
    case ioError(Error)
    case unknownError(Error)
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
