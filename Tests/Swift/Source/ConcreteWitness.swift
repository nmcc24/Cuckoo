/// A class implementing a requirement that names an associated type with the type it gives it.
protocol ConcreteWitnessProducing {
    associatedtype Output
    func make() -> Output
}

class ConcreteWitnessMaker: ConcreteWitnessProducing {
    init() {}
    func make() -> Int { 0 }
}

/// A class implementing a requirement that takes `Self` with its own type.
protocol ConcreteWitnessComparing {
    func isSame(as other: Self) -> Bool
}

class ConcreteWitnessComparer: ConcreteWitnessComparing {
    init() {}
    func isSame(as other: ConcreteWitnessComparer) -> Bool { false }
}

func produced<Producer: ConcreteWitnessProducing>(by producer: Producer) -> Producer.Output {
    producer.make()
}

func areSame<Comparer: ConcreteWitnessComparing>(_ first: Comparer, _ second: Comparer) -> Bool {
    first.isSame(as: second)
}
