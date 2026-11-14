# ``Cuckoo``

Mocks for Swift 6: generated from your sources, stubbed and verified with a Mockito-style API.

## Overview

Cuckoo's generator reads your protocols and classes and writes a mock for each, at build time through a SwiftPM
or Xcode build plugin. Tests stub the mocks' members, run the code under test, and verify the calls it made:

```swift
let mock = MockGreeter()
stub(mock) { stub in
    when(stub.greet(name: any())).thenReturn("Hello")
}

let screen = WelcomeScreen(greeter: mock)
#expect(screen.title == "Hello")

verify(mock).greet(name: "Ann")
```

Mocks keep the isolation of the type they mock: a `@MainActor` protocol gets a `@MainActor` mock, an `actor`
protocol an `actor` mock, and a `Sendable` one a checked `Sendable` mock. They work in Swift Testing and XCTest.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Cuckoofile>
- <doc:StubbingAndVerification>
- <doc:Matching>
- <doc:MigratingFromCuckoo2>
- <doc:Cookbook>

### Mocks

- ``Mock``
- ``ProtocolMock``
- ``ClassMock``
- ``StaticMock``
- ``Mocked``
- ``createMock(_:configuration:)``
- ``createMock(for:configuration:)``
- ``MockBuilder``
- ``StaticStubs``
- ``withStaticStubs(_:)-9n6r1``
- ``withStaticStubs(_:)-33zea``

### Stubbing

- ``stub(_:block:)-(M,_)``
- ``stub(_:block:)-(M.Type,_)``
- ``when(_:)``
- ``clearStubs(_:)``
- ``StubFunctionThenReturnTrait``
- ``StubFunctionThenThrowTrait``
- ``StubFunctionThenTrait``
- ``StubFunctionThenDoNothingTrait``
- ``StubFunctionThenCallRealImplementationTrait``
- ``StubSharing``

### Verification

- ``verify(_:_:fileID:filePath:line:column:)->M.Verification``
- ``verify(_:_:fileID:filePath:line:column:)->M.StaticVerification``
- ``verifyNoMoreInteractions(_:fileID:filePath:line:column:)-(Mock...,_,_,_,_)``
- ``verifyNoMoreInteractions(_:fileID:filePath:line:column:)-(M.Type,_,_,_,_)``
- ``inOrder(strict:fileID:filePath:line:column:_:)``
- ``eventually(timeout:pollingInterval:_:)``
- ``ArgumentCaptor``
- ``reset(_:)-(HasMockManager...)``
- ``reset(_:)-f6hy``
- ``clearInvocations(_:)``

### Call matchers

- ``times(_:)``
- ``never()``
- ``atLeastOnce()``
- ``atLeast(_:)``
- ``atMost(_:)``
- ``CallMatcher``

### Argument matchers

- ``any(_:)->SendableMatcher<T>``
- ``any(_:)->SendableMatcher<T?>``
- ``equal(to:)->ParameterMatcher<[K:V]>``
- ``equal(to:)->ParameterMatcher<[T]>``
- ``equal(to:)->ParameterMatcher<Set<T>>``
- ``equal(to:)-23lxa``
- ``equal(to:)-9r6we``
- ``equal(to:)-8w3fp``
- ``equal(to:)-6c043``
- ``equal(to:)->ParameterMatcher<ParameterPack>``
- ``equal(to:equalWhen:)->ParameterMatcher<T>``
- ``equal(to:equalWhen:)->ParameterMatcher<T?>``
- ``sameInstance(as:)->SendableMatcher<T>``
- ``sameInstance(as:)->SendableMatcher<T?>``
- ``isNil()``
- ``notNil()``
- ``not(_:)->ParameterMatcher<T>``
- ``not(_:)->SendableMatcher<T>``
- ``anyInt()->SendableMatcher<Int>``
- ``anyInt()->SendableMatcher<Int?>``
- ``anyString()->SendableMatcher<String>``
- ``anyString()->SendableMatcher<String?>``
- ``anyClosure()-3btn2``
- ``anyClosure()-9mnq``
- ``anyClosure()-8pwxm``
- ``anyClosure()-27seo``
- ``anyClosure()-9mxzp``
- ``anyClosure()-8acgu``
- ``anyClosure()-2t0qd``
- ``anyClosure()-2q7tr``
- ``anyThrowingClosure()-34xhg``
- ``anyThrowingClosure()-6dz20``
- ``anyThrowingClosure()-1t3rz``
- ``anyThrowingClosure()-2uaf``
- ``anyThrowingClosure()-9z0m8``
- ``anyThrowingClosure()-1ozlh``
- ``anyThrowingClosure()-5jlos``
- ``anyThrowingClosure()-9fker``
- ``anyClosure()-13sm5``
- ``anyClosure()-7q1ie``
- ``anyClosure()-24w4o``
- ``anyClosure()-79a5d``
- ``anyClosure()-2q2yh``
- ``anyClosure()-9hhhj``
- ``anyClosure()-4lapl``
- ``anyClosure()-57acv``
- ``anyThrowingClosure()-2ynlg``
- ``anyThrowingClosure()-5i84v``
- ``anyThrowingClosure()-8mb02``
- ``anyThrowingClosure()-975js``
- ``anyThrowingClosure()-18kwe``
- ``anyThrowingClosure()-7jo2n``
- ``anyThrowingClosure()-7muqc``
- ``anyThrowingClosure()-4xyp4``
- ``anyClosure()-4jd9l``
- ``anyClosure()-9i0bz``
- ``anyClosure()-a99v``
- ``anyClosure()-706qa``
- ``anyClosure()-9oglu``
- ``anyClosure()-kpo6``
- ``anyClosure()-8bot8``
- ``anyClosure()-5qiop``
- ``anyThrowingClosure()-9y7z2``
- ``anyThrowingClosure()-13i2n``
- ``anyThrowingClosure()-7vryi``
- ``anyThrowingClosure()-2c8``
- ``anyThrowingClosure()-3m02x``
- ``anyThrowingClosure()-3461d``
- ``anyThrowingClosure()-15nm0``
- ``anyThrowingClosure()-7gyul``
- ``anyClosure()-1qmdu``
- ``anyClosure()-2mhtk``
- ``anyClosure()-1komu``
- ``anyClosure()-7rvt``
- ``anyClosure()-2u2x4``
- ``anyClosure()-4uhp6``
- ``anyClosure()-3jcoh``
- ``anyClosure()-7n78z``
- ``anyThrowingClosure()-1rtv6``
- ``anyThrowingClosure()-78bvz``
- ``anyThrowingClosure()-2pc9k``
- ``anyThrowingClosure()-1mjcm``
- ``anyThrowingClosure()-8qcgc``
- ``anyThrowingClosure()-1l5e8``
- ``anyThrowingClosure()-7svb9``
- ``anyThrowingClosure()-172sf``
- ``anyClosure()-52rw1``
- ``anyClosure()-s6zj``
- ``anyClosure()-1tu01``
- ``anyClosure()-6kbp7``
- ``anyClosure()-86nkz``
- ``anyClosure()-6b93y``
- ``anyClosure()-8kld2``
- ``anyClosure()-3b6q8``
- ``anyClosure()-5t23j``
- ``anyClosure()-7kbxl``
- ``anyClosure()-9xlaz``
- ``anyClosure()-8a1n5``
- ``anyClosure()-9g1cf``
- ``anyClosure()-k2lp``
- ``anyClosure()-arg2``
- ``anyClosure()-fjo7``
- ``anyThrowingClosure()->SendableMatcher<(((IN1,IN2,IN3,IN4,IN5,IN6,IN7))->OUT)?>``
- ``anyThrowingClosure()->SendableMatcher<(((IN1,IN2,IN3,IN4,IN5,IN6))->OUT)?>``
- ``anyThrowingClosure()->SendableMatcher<(((IN1,IN2,IN3,IN4,IN5))->OUT)?>``
- ``anyThrowingClosure()->SendableMatcher<(((IN1,IN2,IN3,IN4))->OUT)?>``
- ``anyThrowingClosure()->SendableMatcher<(((IN1,IN2,IN3))->OUT)?>``
- ``anyThrowingClosure()->SendableMatcher<(((IN1,IN2))->OUT)?>``
- ``anyThrowingClosure()->SendableMatcher<((IN1)->OUT)?>``
- ``anyThrowingClosure()->SendableMatcher<(()->OUT)?>``
- ``anyClosure()-4bdo5``
- ``anyClosure()-52njt``
- ``anyClosure()-fvhu``
- ``anyClosure()-1j9mg``
- ``anyClosure()-5rb67``
- ``anyClosure()-6fnac``
- ``anyClosure()-9n7bw``
- ``anyClosure()-9pycw``
- ``anyClosure()-6egsg``
- ``anyClosure()-4pmr7``
- ``anyClosure()-4x81e``
- ``anyClosure()-216wf``
- ``anyClosure()-4p9gi``
- ``anyClosure()-5unru``
- ``anyClosure()-1a3ik``
- ``anyClosure()-6h7oz``
- ``anyOptionalThrowingClosure()``
- ``ParameterMatcher``
- ``SendableMatcher``
- ``equal(to:)-15xi2``
- ``equal(to:)-1x32e``
- ``equal(to:)-35lvn``
- ``equal(to:)-4j92q``
- ``equal(to:)-6g87p``
- ``equal(to:)-9hv7``
- ``equal(to:equalWhen:)-15lez``
- ``equal(to:equalWhen:)-4y5uy``

### Collection matchers

- ``containsAllOf(_:)-515d3``
- ``containsAllOf(_:)-4avwb``
- ``containsAllOf(_:)-4f3kv``
- ``containsAllOf(_:)->ParameterMatcher<[K:V]>``
- ``containsAnyOf(_:)-2lxlf``
- ``containsAnyOf(_:)-6dhn8``
- ``containsAnyOf(_:)->ParameterMatcher<[K:V]>``
- ``containsNoneOf(_:)-3hhr1``
- ``containsNoneOf(_:)-921d``
- ``containsNoneOf(_:)->ParameterMatcher<[K:V]>``
- ``containsAllKeysOf(_:)->ParameterMatcher<[S.Element:V]>``
- ``containsAllKeysOf(_:)->SendableMatcher<[S.Element:V]>``
- ``containsAnyKeysOf(_:)->ParameterMatcher<[S.Element:V]>``
- ``containsAnyKeysOf(_:)->SendableMatcher<[S.Element:V]>``
- ``containsNoKeysOf(_:)->ParameterMatcher<[S.Element:V]>``
- ``containsNoKeysOf(_:)->SendableMatcher<[S.Element:V]>``
- ``containsAllValuesOf(_:)-8984q``
- ``containsAllValuesOf(_:)-3zw76``
- ``containsAnyValuesOf(_:)-6iagv``
- ``containsAnyValuesOf(_:)-9w7t3``
- ``containsNoValuesOf(_:)-3swwg``
- ``containsNoValuesOf(_:)-3mh3c``
- ``hasLength(exactly:)``
- ``hasLength(atLeast:inclusive:)``
- ``hasLength(atMost:inclusive:)``
- ``hasLength(in:)``
- ``containsAllKeysOf(values:)-4779e``
- ``containsAllKeysOf(values:)-7j88v``
- ``containsAllOf(_:)-38wjt``
- ``containsAllOf(_:)-6ujgh``
- ``containsAllOf(_:)-9oeht``
- ``containsAllOf(_:)-9uz1c``
- ``containsAllOf(_:where:)-4r1t9``
- ``containsAllOf(_:where:)-6o1oo``
- ``containsAllOf(_:where:)-7s6w7``
- ``containsAllOf(_:where:)-7tr53``
- ``containsAllOf(values:)-2c9w2``
- ``containsAllOf(values:)-2s4l3``
- ``containsAllOf(values:)-8ybg6``
- ``containsAllOf(values:)-9hs21``
- ``containsAllOf(values:where:)-68pow``
- ``containsAllOf(values:where:)-938pt``
- ``containsAllValuesOf(_:)-6yarb``
- ``containsAllValuesOf(_:)-79kb2``
- ``containsAllValuesOf(_:where:)-2hihl``
- ``containsAllValuesOf(_:where:)-3b8ed``
- ``containsAllValuesOf(values:)-4c1vz``
- ``containsAllValuesOf(values:)-739cw``
- ``containsAllValuesOf(values:)-9s8yh``
- ``containsAllValuesOf(values:)-yi9a``
- ``containsAllValuesOf(values:where:)-790wh``
- ``containsAllValuesOf(values:where:)-99mcd``
- ``containsAnyKeysOf(values:)-4gs0e``
- ``containsAnyKeysOf(values:)-6vaaj``
- ``containsAnyOf(_:)-299n7``
- ``containsAnyOf(_:)-5pvhw``
- ``containsAnyOf(_:)-6zxmr``
- ``containsAnyOf(_:where:)-3ukoi``
- ``containsAnyOf(_:where:)-6efto``
- ``containsAnyOf(_:where:)-6ertk``
- ``containsAnyOf(_:where:)-7lho8``
- ``containsAnyOf(values:)-15y6j``
- ``containsAnyOf(values:)-4mpon``
- ``containsAnyOf(values:)-6lvka``
- ``containsAnyOf(values:)-6lw1l``
- ``containsAnyOf(values:where:)-1d9nz``
- ``containsAnyOf(values:where:)-7jkyp``
- ``containsAnyValuesOf(_:)-5mc15``
- ``containsAnyValuesOf(_:)-7wal9``
- ``containsAnyValuesOf(_:where:)-39t7h``
- ``containsAnyValuesOf(_:where:)-9qzt4``
- ``containsAnyValuesOf(values:)-31tky``
- ``containsAnyValuesOf(values:)-3hvd0``
- ``containsAnyValuesOf(values:)-7xi9t``
- ``containsAnyValuesOf(values:)-9d0d``
- ``containsAnyValuesOf(values:where:)-6a3v3``
- ``containsAnyValuesOf(values:where:)-m83c``
- ``containsNoKeysOf(values:)-3qetf``
- ``containsNoKeysOf(values:)-92hf0``
- ``containsNoValuesOf(_:)-1jznc``
- ``containsNoValuesOf(_:)-599zb``
- ``containsNoValuesOf(_:where:)-11iq5``
- ``containsNoValuesOf(_:where:)-3k585``
- ``containsNoValuesOf(values:)-25fb7``
- ``containsNoValuesOf(values:)-3anwk``
- ``containsNoValuesOf(values:)-72rd1``
- ``containsNoValuesOf(values:)-gxyp``
- ``containsNoValuesOf(values:where:)-68imt``
- ``containsNoValuesOf(values:where:)-7pwo``
- ``containsNoneOf(_:)-2kjwv``
- ``containsNoneOf(_:)-33fhq``
- ``containsNoneOf(_:)-7zq22``
- ``containsNoneOf(_:where:)-5ti9s``
- ``containsNoneOf(_:where:)-65re4``
- ``containsNoneOf(_:where:)-7yv0k``
- ``containsNoneOf(_:where:)-8sih8``
- ``containsNoneOf(values:)-1ysyc``
- ``containsNoneOf(values:)-5ms0o``
- ``containsNoneOf(values:)-6i7w1``
- ``containsNoneOf(values:)-fn3m``
- ``containsNoneOf(values:where:)-4jb03``
- ``containsNoneOf(values:where:)-9i3s1``

### Special arguments

- ``ParameterPack``
- ``NoncopyableArgument``

### Configuration

- ``CuckooConfiguration``
- ``CuckooTrait``
- ``DefaultValues``
- ``DefaultValueRegistry``
- ``CuckooError``

### Support for generated mocks

These are public because generated mocks use them. Tests don't need them directly.

- ``MockManager``
- ``HasMockManager``
- ``HasSuperclass``
- ``StubbingProxy``
- ``VerificationProxy``
- ``DefaultImplementation``
- ``Stub``
- ``ConcreteStub``
- ``ClassConcreteStub``
- ``StubCall``
- ``ConcreteStubCall``
- ``BaseStubFunctionTrait``
- ``StubFunction``
- ``StubNoReturnFunction``
- ``StubThrowingFunction``
- ``StubNoReturnThrowingFunction``
- ``ProtocolStubFunction``
- ``ProtocolStubNoReturnFunction``
- ``ProtocolStubThrowingFunction``
- ``ProtocolStubNoReturnThrowingFunction``
- ``ClassStubFunction``
- ``ClassStubNoReturnFunction``
- ``ClassStubThrowingFunction``
- ``ClassStubNoReturnThrowingFunction``
- ``ToBeStubbedProperty``
- ``ToBeStubbedReadOnlyProperty``
- ``ToBeStubbedOptionalProperty``
- ``ToBeStubbedThrowingProperty``
- ``ProtocolToBeStubbedProperty``
- ``ProtocolToBeStubbedReadOnlyProperty``
- ``ProtocolToBeStubbedOptionalProperty``
- ``ProtocolToBeStubbedThrowingProperty``
- ``ClassToBeStubbedProperty``
- ``ClassToBeStubbedReadOnlyProperty``
- ``ClassToBeStubbedOptionalProperty``
- ``ClassToBeStubbedThrowingProperty``
- ``VerifyProperty``
- ``VerifyReadOnlyProperty``
- ``VerifyOptionalProperty``
- ``CuckooOptionalType``
- ``SourceLocation``
- ``wrap(matchable:mapping:)-(_,(IN)->M.OptionalMatchedType?)``
- ``wrap(matchable:mapping:)-(_,(IN)->M.MatchedType)``
- ``wrap(matchable:at:)-804pr``
- ``wrap(matchable:at:)-9e0kn``

### Deprecated

- ``hasLength(inRange:)``
- ``hasLength(inRange:inclusive:)``
- ``Matchable``
- ``OptionalMatchable``
