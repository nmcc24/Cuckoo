// Types declared in an extension of a `nonisolated` type. With `-default-isolation MainActor` Swift gives them the
// default isolation, unlike the ones declared in the type's own body, which are nonisolated as it is: the mocks
// take the default too, or their overrides and conformances wouldn't compile in that mode.
nonisolated struct Holder {
    struct Inner {}

    class InBody {
        init() {}
        func x() {}
    }
}

extension Holder {
    class Nested {
        init() {}
        func x() {}
    }

    protocol Listening {
        func listen()
    }

    struct Middle {
        class Deeper {
            init() {}
            func x() {}
        }
    }
}

extension Holder.Inner {
    class Deep {
        init() {}
        func x() {}
    }
}

extension Holder.InBody {
    class Deep {
        init() {}
        func x() {}
    }
}

// A class nonisolated through its superclass, and a `nonisolated` extension, whose own members are nonisolated but
// not the types it declares.
nonisolated class Plain {
    init() {}
}

class PlainChild: Plain {}

extension PlainChild {
    class Deep {
        init() {}
        func x() {}
    }
}

enum Space {}

nonisolated extension Space {
    class Leaf {
        init() {}
        func x() {}
    }

    protocol Leafing {
        func leaf()
    }
}

// Callable without an actor in every mode: the type declared in the body of the `nonisolated` type.
nonisolated func callInBody(_ mock: Holder.MockInBody) {
    mock.x()
}

@MainActor
func callNested(_ nested: Holder.MockNested, _ deep: Holder.Inner.MockDeep, _ leaf: Space.MockLeaf, _ listening: Holder.MockListening) {
    nested.x()
    deep.x()
    leaf.x()
    listening.listen()
}
