import SwiftUI

@main
struct SwiftDataTestApp: App {

    var body: some Scene {
        WindowGroup {
            AppView(coordinator: .init())
        }
    }
}
