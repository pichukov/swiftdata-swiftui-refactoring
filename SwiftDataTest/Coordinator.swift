import Observation
import SwiftData
import SwiftUI

@Observable
final class Coordinator {

    var rootView: AnyView = AnyView(EmptyView())

    private var modelContainer: ModelContainer?

    init() {
        Task { @MainActor in
            setUpView()
        }
    }

    @MainActor
    private func setUpView() {
        guard let modelContainer = try? ModelContainer(for: ItemModel.self) else {
            // Error handling
            return
        }
        self.modelContainer = modelContainer
        rootView = AnyView(
            ContentView(
                viewModel: ViewModel(
                    dataProvider: DataProvider(
                        context: modelContainer.mainContext
                    )
                )
            )
        )
    }
}
