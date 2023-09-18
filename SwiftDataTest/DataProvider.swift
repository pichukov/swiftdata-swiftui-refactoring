import Foundation
import SwiftData

protocol DataProvidable: AnyObject {
    func getItems() throws -> [Item]
    func set(item: Item) throws
}

class DataProvider: DataProvidable {

    private var context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func getItems() throws -> [Item] {
        let items = try context.fetch(FetchDescriptor<ItemModel>())
        return items.map { Item(timestamp: $0.timestamp) }
    }

    func set(item: Item) throws {
        context.insert(
            ItemModel(timestamp: item.timestamp)
        )
        try context.save()
    }
}

class MockDataProvider: DataProvidable {

    func getItems() throws -> [Item] {
        return [
            Item(timestamp: Date())
        ]
    }
    
    func set(item: Item) throws { }
}
