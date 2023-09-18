import Foundation
import Observation

@Observable
final class ViewModel {

    var items: [Item] = []
    private let dataProvider: DataProvidable

    init(dataProvider: DataProvidable) {
        self.dataProvider = dataProvider
        do {
            items = try dataProvider.getItems()
        } catch {
            // Error handling
        }
    }

    func onAdd() {
        let item = Item(timestamp: Date())
        do {
            try dataProvider.set(item: item)
            items.append(item)
        } catch {
            // Error handling
        }
    }
}
