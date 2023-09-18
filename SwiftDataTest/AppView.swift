import SwiftUI

struct AppView: View {

    private var coordinator: Coordinator

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        coordinator.rootView
    }
}

#Preview {
    AppView(coordinator: .init())
}
