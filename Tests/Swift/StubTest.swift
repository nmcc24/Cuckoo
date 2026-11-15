import Cuckoo
import Testing
@testable import CuckooMocks
@testable import CuckooTestSources

struct StubTest {
    let stub = ClassForStubTestingStub()

    @Test
    func intProperty() {
        stub.intProperty = 1
        #expect(stub.intProperty == 0)
    }

    @Test
    func arrayProperty() {
        stub.arrayProperty = [1]
        #expect(stub.arrayProperty == [])
    }

    @Test
    func setProperty() {
        stub.setProperty = Set([1])
        #expect(stub.setProperty == Set())
    }

    @Test
    func dictionaryProperty() {
        stub.dictionaryProperty = ["a": 1]
        #expect(stub.dictionaryProperty == [:])
    }

    @Test
    func tuple2() {
        stub.tuple2 = (2, 1)
        #expect(stub.tuple2 == (0, 0))
    }

    @Test
    func tuple7() {
        stub.tuple7 = (2, 2, 2, 2, 2, 2, 2)
        let value = stub.tuple7
        #expect([value.0, value.1, value.2, value.3, value.4, value.5, value.6] == [0, 0, 0, 0, 0, 0, 0])
    }

    @Test
    func tupleWithOptionalAndArray() {
        stub.tupleWithOptionalAndArray = (2, "B", [2])
        let value = stub.tupleWithOptionalAndArray
        #expect(value.0 == 0)
        #expect(value.1 == nil)
        #expect(value.2 == [])
    }

    @Test
    func intFunction() {
        stub.intProperty = 1
        #expect(stub.intFunction() == 0)
    }

    @Test
    func arrayFunction() {
        stub.arrayProperty = [1]
        #expect(stub.arrayFunction() == [])
    }

    @Test
    func setFunction() {
        stub.setProperty = Set([1])
        #expect(stub.setFunction() == Set())
    }

    @Test
    func dictionaryFunction() {
        stub.dictionaryProperty = ["a": 1]
        #expect(stub.dictionaryFunction() == [:])
    }

    @Test
    func voidFunction() {
        // Test for crash
        stub.voidFunction()
    }
}
