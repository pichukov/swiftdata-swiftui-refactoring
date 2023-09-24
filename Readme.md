# SwiftData DI in SwiftUI application without Environment.

Most of the examples Apple provides to demonstrate Dependency Injection in SwiftUI use `@Environment`. When creating a new project with `SwiftData` in XCode, you'll notice that the template uses `Environment` for injecting the `modelContext`.

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext // <-- 1
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ...
            }
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        ...
                    }
                }
            }
        }
        ...
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem) // <-- 2
        }
    }

    ...
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true) // <-- 3
}
```

But what exactly is wrong here? For simple applications, nothing may be amiss, and this approach should function perfectly. However, when working on a rapidly growing application with a large codebase and multiple developers involved, we may encounter some scaling issues. Let's take a closer look at our current setup:

1. We use the `@Environment` property wrapper to gain access to the `Environment` context of the View. Considering `Environment` as a sort of Dependency Injection (DI) container for the entire View hierarchy, we can place any dependencies at a high level and retrieve them in any other view below (`modelContext`), making dependency injection significantly simpler in SwiftUI.
2. We use `modelContext`, which we just retrieved from `Environment`, to insert a new item.
3. We are setting up a `modelContainer` with the given type available in the scope of our View.

Let's try to challenge this approach:

- I will start by addressing the main issue that we often see in Apple-provided examples: combining UI and Business Logic in the same function. In our `addItem` function, we are doing something that our View should not be aware of. We are violating the Single Responsibility Principle (SRP) by having the View handle both UI and business logic, when ideally, the View should only be responsible for handling user input and notifying another object about it. The specific actions taken by the other object with this information should not be the responsibility of the View.

- We are working at the implementation level, not at an interface level. The `modelContext` is an instance of `ModelContext`, a class and not a protocol, which means we have direct access to the object instance. As such, we can directly manipulate the object's properties and methods without any abstraction or indirection. For example, if we need to retrieve this data from the network or use another data provider in the future, we will need to update our View implementation accordingly.

- We do not control the lifecycle of the `modelContext`.

- We assume here that the data we store is the same data we want to present, which is why we have `@Query private var items: [Item]` that will automatically trigger a UI update when we add a new item to the list. However, this is not always the case. You may store additional information that you use to prepare a final result for the user, and your UI may not always be an exact reflection of your data schema.

### Target solution

Let's try to think about how we can refactor it in a way that solves all the issues listed above.
Here is our current diagram:

<div align="center">
  <img width="400" src="https://raw.githubusercontent.com/pichukov/PublicAssets/master/SwiftData/swift-data-old.png">
</div>

And let's take a look at the diagram we want to achieve:

<div align="center">
  <img width="400" src="https://raw.githubusercontent.com/pichukov/PublicAssets/master/SwiftData/swift-data-new.png">
</div>

### Separate Data Layer

First of all, let's separate the data layer from the view and make it a bit more generic. I will add a protocol called `DataProvidable` and a `DataProvider` class that will sit behind this protocol. As we all know, naming is one of the most challenging aspects of software development, so perhaps `DataProvidable` is not the best name, but I've chosen it because it does exactly what its name suggests - provide data.

```swift
protocol DataProvidable: AnyObject {
    func getItems() throws -> [Item]
    func set(item: Item) throws
}
```

Let's also create a separate class for the model that we will store in persistent storage:

```swift
@Model
final class ItemModel {

    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
```

And the model that we will use in SwiftUI and our ViewModel is the following:

```swift
struct Item: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
}
```

Now we have a good foundation to move forward with the solution, and the view and view model are decoupled from the way we are storing and providing data. Since we have a protocol for our data layer, let's implement something behind it:

```swift
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
```

We get injected with a `ModelContext`, and we do not expose it to the outside world. So the `DataProvider` only knows how we store the data and where we obtain it from. Another benefit is that it allows us to create a very simple `MockDataProvider` that can be used in SwiftUI previews:

```swift
class MockDataProvider: DataProvidable {

    func getItems() throws -> [Item] {
        return [
            Item(timestamp: Date())
        ]
    }

    func set(item: Item) throws { }
}
```

### View and ViewModel

Since we have our data layer and have mentioned the `ViewModel` several times, let's finally create it:

```swift
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
```

We do not use the exact `DataProvider` type here, but the protocol, which gives us the ability to inject anything that will be behind it and work on the interface level, not the implementation. For example, with such an implementation, we can easily cover this `ViewModel` with unit tests in a fully isolated environment.

Let's also update our view by utilizing everything we've previously created:

```swift
struct ContentView: View {

    private let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationSplitView {
            List {
                ...
            }
            .toolbar {
                ToolbarItem {
                    Button(action: viewModel.onAdd) {
                        ...
                    }
                }
            }
        }
        ...
    }
}

#Preview {
    ContentView(
        viewModel: ViewModel(
            dataProvider: MockDataProvider()
        )
    )
}
```

As you can see, we no longer have a `SwiftData` dependency in the `View`. We are also using our `MockDataProvider` to make preview work, and we can play with the data there the way we want to present any kind of data in the `SwiftUI` preview. There is no business logic in the `View` anymore. All we do is just call the `onAdd` function from the `ViewModel`

### How to use it in the app now ?

Currently, our implementation of `View` takes an instance of `ViewModel` injected. Our `View` + `ViewModel` is now a standalone, isolated component that can be used anywhere in the app. However, for the sake of completeness, let's explore one architecture option that we could use in the application.

First, let's create a `Coordinator` that will be responsible for providing a `View` that is currently being presented in the app:

```swift
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
```

To keep things simple, we will also prepare all the dependencies in the coordinator as well. In more complex applications, all the responsibilities can be decoupled into separate components like `Router`, `ViewFactory`, etc.

In the `setUpView` function, we are preparing the `ContentView`. Now, we need to create an additional high-level `View` that will serve as a container for our application:

```swift
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
```

This view gets `Coordinator` injected very similarly to the way we implemented it with a `View` and `ViewModel`.
The last step of our exercise will be to update the entry point to our application:

```swift
@main
struct SwiftDataTestApp: App {

    var body: some Scene {
        WindowGroup {
            AppView(coordinator: .init())
        }
    }
}
```

### Conclusion

We went through a simple refactoring of default SwiftData example from Apple. Here is a short summary of what we have achived:

In conclusion, we have refactored the default SwiftData example from Apple to create a more modular and maintainable architecture for our application. Here is a brief overview of what we have accomplished:

- Removed `SwiftData` from the `View` component
- Separated the `View` and `ViewModel` components
- Created a separate data layer that is hidden by the `DataProvidable` protocol
- Added a `DataProvider` component with `SwiftData` logic
- Used a pure dependency injection approach through the `init` method instead of using `Environment`

Such refactoring will make our code more flexible, testable, and more aligned with SOLID principles than we had before. Keep in mind that this is just one of many options for structuring our application architecture. If we have a very simple basic app that works alone, the approach suggested by Apple may work for us. However, if we are building an application with multiple developers working on the same codebase, covering it with tests, and planning for possible changes and updates in the future, we may need to consider alternative approaches, and the example presented above is one of the options.
