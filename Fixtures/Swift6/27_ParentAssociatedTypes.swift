protocol Repository {
    associatedtype Item
    associatedtype ID: Hashable
    func fetch(id: ID) -> Item?
}

protocol CachedRepository: Repository {
    func cached() -> [Item]
    func evict(id: ID)
}

protocol PrimaryRepository<Element> {
    associatedtype Element
    func all() -> [Element]
}

protocol SortedRepository: PrimaryRepository {
    func sorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element]
}

protocol StringRepository: Repository where Item == String {
    func joined() -> String
}

protocol IntRepository: PrimaryRepository<Int> {
    func sum() -> Element
}

protocol HashedRepository: CachedRepository where Item: Hashable {
    func uniqued() -> Set<Item>
}

protocol AuditedRepository: CachedRepository, SortedRepository {
    func audit() -> (Item?, [Element])
}
