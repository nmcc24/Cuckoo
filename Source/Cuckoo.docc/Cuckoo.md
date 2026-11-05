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

- ``verify(_:_:file:fileID:filePath:line:column:)->M.Verification``
- ``verify(_:_:file:fileID:filePath:line:column:)->M.StaticVerification``
- ``verifyNoMoreInteractions(_:file:fileID:filePath:line:column:)-(M...,_,_,_,_,_)``
- ``verifyNoMoreInteractions(_:file:fileID:filePath:line:column:)-(M.Type,_,_,_,_,_)``
- ``inOrder(strict:file:fileID:filePath:line:column:_:)``
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

- ``any(_:)->ParameterMatcher<T>``
- ``any(_:)->ParameterMatcher<T?>``
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
- ``sameInstance(as:)->ParameterMatcher<T>``
- ``sameInstance(as:)->ParameterMatcher<T?>``
- ``isNil()``
- ``notNil()``
- ``not(_:)``
- ``anyInt()->ParameterMatcher<Int>``
- ``anyInt()->ParameterMatcher<Int?>``
- ``anyString()->ParameterMatcher<String>``
- ``anyString()->ParameterMatcher<String?>``
- ``anyClosure()-7oblr``
- ``anyClosure()-7bero``
- ``anyClosure()-zprn``
- ``anyClosure()-30u8l``
- ``anyClosure()-24od7``
- ``anyClosure()-8wll5``
- ``anyClosure()-27i11``
- ``anyClosure()-3zt05``
- ``anyClosure()-5expx``
- ``anyClosure()-8ou8v``
- ``anyClosure()-1fjk5``
- ``anyClosure()-laij``
- ``anyClosure()-5ommb``
- ``anyClosure()-467cv``
- ``anyClosure()-62c3a``
- ``anyClosure()-37dmd``
- ``anyClosure()-ufkp``
- ``anyClosure()-9p2s5``
- ``anyClosure()-9x0e``
- ``anyClosure()-rp4t``
- ``anyClosure()-4dh81``
- ``anyClosure()-3fmux``
- ``anyClosure()-7cfkd``
- ``anyClosure()-4qcnz``
- ``anyClosure()-3rjni``
- ``anyClosure()-8hlt8``
- ``anyClosure()-28ize``
- ``anyClosure()-4hyxs``
- ``anyClosure()-7ce2b``
- ``anyClosure()-824qk``
- ``anyClosure()-37kld``
- ``anyClosure()-9m1ad``
- ``anyClosure()-8y0zz``
- ``anyClosure()-4b4j8``
- ``anyClosure()-9k7tp``
- ``anyClosure()-7kbzq``
- ``anyClosure()-6a4v5``
- ``anyClosure()-5ut6r``
- ``anyClosure()-11rvj``
- ``anyClosure()-5dx7h``
- ``anyClosure()-35te0``
- ``anyClosure()-6hx2t``
- ``anyClosure()-20vrv``
- ``anyClosure()-4c07z``
- ``anyClosure()-31wqc``
- ``anyClosure()-4ac47``
- ``anyClosure()-66qpa``
- ``anyClosure()-6pr04``
- ``anyClosure()-24g49``
- ``anyClosure()-6y9it``
- ``anyClosure()-68zuw``
- ``anyClosure()-61jf5``
- ``anyClosure()-13r4w``
- ``anyClosure()-18h60``
- ``anyClosure()-9wavs``
- ``anyClosure()-7mzgb``
- ``anyClosure()-8w0nj``
- ``anyClosure()-86dis``
- ``anyClosure()-31hao``
- ``anyClosure()-7kl5v``
- ``anyClosure()-95whi``
- ``anyClosure()-5hgw1``
- ``anyClosure()-1gwtk``
- ``anyClosure()-3yft1``
- ``anyThrowingClosure()->ParameterMatcher<(((IN1,IN2,IN3,IN4,IN5,IN6,IN7))->OUT)?>``
- ``anyThrowingClosure()-6niu9``
- ``anyThrowingClosure()-1hv6b``
- ``anyThrowingClosure()-4jtn9``
- ``anyThrowingClosure()-22hf1``
- ``anyThrowingClosure()->ParameterMatcher<(((IN1,IN2,IN3,IN4,IN5,IN6))->OUT)?>``
- ``anyThrowingClosure()-33a48``
- ``anyThrowingClosure()-8mhs5``
- ``anyThrowingClosure()-5xr79``
- ``anyThrowingClosure()-288k4``
- ``anyThrowingClosure()->ParameterMatcher<(((IN1,IN2,IN3,IN4,IN5))->OUT)?>``
- ``anyThrowingClosure()-wjl8``
- ``anyThrowingClosure()-65y5r``
- ``anyThrowingClosure()-73y69``
- ``anyThrowingClosure()-4tkjw``
- ``anyThrowingClosure()->ParameterMatcher<(((IN1,IN2,IN3,IN4))->OUT)?>``
- ``anyThrowingClosure()-9mry3``
- ``anyThrowingClosure()-4xmd3``
- ``anyThrowingClosure()-93if8``
- ``anyThrowingClosure()-5jsng``
- ``anyThrowingClosure()->ParameterMatcher<(((IN1,IN2,IN3))->OUT)?>``
- ``anyThrowingClosure()-qbzr``
- ``anyThrowingClosure()-7c2y``
- ``anyThrowingClosure()-ed1b``
- ``anyThrowingClosure()-19vqt``
- ``anyThrowingClosure()->ParameterMatcher<(((IN1,IN2))->OUT)?>``
- ``anyThrowingClosure()-5984t``
- ``anyThrowingClosure()-3kd9v``
- ``anyThrowingClosure()-6aorx``
- ``anyThrowingClosure()-99xaj``
- ``anyThrowingClosure()->ParameterMatcher<((IN1)->OUT)?>``
- ``anyThrowingClosure()-2d5lo``
- ``anyThrowingClosure()-4c3s4``
- ``anyThrowingClosure()-7dkc5``
- ``anyThrowingClosure()-4hra0``
- ``anyThrowingClosure()->ParameterMatcher<(()->OUT)?>``
- ``anyThrowingClosure()-4kij8``
- ``anyThrowingClosure()-4cbzq``
- ``anyThrowingClosure()-4fr23``
- ``anyThrowingClosure()-94uhy``
- ``anyOptionalThrowingClosure()``
- ``ParameterMatcher``
- ``Matchable``
- ``OptionalMatchable``

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
- ``containsAllKeysOf(_:)``
- ``containsAnyKeysOf(_:)``
- ``containsNoKeysOf(_:)``
- ``containsAllValuesOf(_:)-8984q``
- ``containsAllValuesOf(_:)-3zw76``
- ``containsAnyValuesOf(_:)-6iagv``
- ``containsAnyValuesOf(_:)-9w7t3``
- ``containsNoValuesOf(_:)-3swwg``
- ``containsNoValuesOf(_:)-3mh3c``
- ``hasLength(exactly:)``
- ``hasLength(atLeast:inclusive:)``
- ``hasLength(atMost:inclusive:)``
- ``hasLength(inRange:inclusive:)``

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
