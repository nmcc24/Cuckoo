// A Swift issue, not Cuckoo's: under `-default-isolation MainActor`, a subclass of a class that relies on its
// implicit `init()` doesn't compile (`class Base {}; final class Sub: Base {}` fails without Cuckoo too, Swift
// 6.2 to 6.4), so a mock of such a class doesn't either. Expected to fail in that mode only, with that message:
// when it passes, Swift has fixed it, and the fixtures that declare `init() {}` for it no longer need to.
class ImplicitInitService {
    func run() {}
}
