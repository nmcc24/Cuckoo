import Testing
@testable import CuckooGenerator

struct OrderedSetTest {
    @Test
    func initializers() {
        _ = OrderedSet<Int>()
        _ = [] as OrderedSet<String>
        _ = ["1", "2", "4"] as OrderedSet<String>
    }

    @Test
    func empty() {
        let set = OrderedSet<Double>()
        #expect(set.values == [])
    }

    @Test
    func basicUsage() {
        var set = OrderedSet<Int>()
        set.insert(2)
        #expect(set.values == [2])
        set.insert(0)
        #expect(set.values == [2, 0])
        set.insert(1)
        #expect(set.values == [2, 0, 1])
    }

    @Test
    func deduplicationInit() {
        let set: OrderedSet<Int> = [1, 2, 3, 2, 0, 1]
        #expect(set.values == [1, 2, 3, 0])
    }

    @Test
    func deduplicationInsert() {
        var set = OrderedSet<String>()
        set.insert("1")
        #expect(set.values == ["1"])
        set.insert("11")
        #expect(set.values == ["1", "11"])
        set.insert("111")
        #expect(set.values == ["1", "11", "111"])
        set.insert("11")
        #expect(set.values == ["1", "11", "111"])
        set.insert("1")
        #expect(set.values == ["1", "11", "111"])
    }

    @Test
    func remove() {
        var set: OrderedSet<String> = ["gg", "bg", "wp", "ez"]
        set.remove("ez")
        #expect(set.values == ["gg", "bg", "wp"])
        set.remove("bg")
        #expect(set.values == ["gg", "wp"])
    }

    @Test
    func contains() {
        var set: OrderedSet<Int> = [1, 2, 3, 4, 5]
        #expect(!set.contains(6))
        #expect(set.contains(1))
        set.insert(6)
        #expect(set.contains(6))
        set.remove(2)
        #expect(!set.contains(2))
    }

    @Test
    func intersection() {
        let set1: OrderedSet<Int> = [1, 2, 3, 4]
        let set2: OrderedSet<Int> = [2, 3, 4, 5]
        #expect(set1.intersection(set2).values == [2, 3, 4])
        #expect(set1.values == [1, 2, 3, 4])
        #expect(set2.values == [2, 3, 4, 5])
    }

    @Test
    func union() {
        let set1: OrderedSet<Int> = [1, 2, 3, 4]
        let set2: OrderedSet<Int> = [2, 3, 4, 5]
        #expect(set1.union(set2).values == [1, 2, 3, 4, 5])
        #expect(set1.values == [1, 2, 3, 4])
        #expect(set2.values == [2, 3, 4, 5])
    }
}
