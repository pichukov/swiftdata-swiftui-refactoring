import Foundation
import SwiftData

@Model
final class ItemModel {

    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
