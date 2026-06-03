# StateTree 🪾

#### *Your app is not its UI.*

StateTree is an experimental Swift framework that models an application's domain
as a **tree of value-type nodes**, kept separate from its user interface.
Business logic, navigation, side effects, and state are expressed as a single
serializable, replayable model. The user interface — SwiftUI, UIKit, AppKit, or
none — observes that model rather than housing it.

> ### Research project — 2023, the pre-`@Observable` era
>
> StateTree was written in 2023, before Swift's `@Observable` macro and the
> Observation framework, and before the language's concurrency model had settled.
> It investigates how far a fully UI-decoupled, serializable, reactive domain
> model could be taken in the Swift of that period, and so provides its own
> observation layer based on a hand-rolled ReactiveX implementation, alongside
> its own dependency injection, routing, and side-effect systems.
>
> Some of the problems it addresses were later resolved at the language and SDK
> level. Others remain absent from any common production systems.
> 
> It is best read as an exploration of the questions "Why is everything centered
> around the UI — when doing so inherently prevents re-use?" and "What can we do about it?"
> 
> In considering the former question, it's worth noting that platfrom companies
> are strongly disincentivized to help make their end-user-experiences a commodity.

---

## The idea

Most application architectures bind domain logic to the view layer: to `View`
structs, view controllers, or view models that exist primarily to feed a screen.
StateTree inverts that relationship. The application is a tree of `Node`s, each a
plain `struct` describing one part of the domain, and the user interface is an
optional, interchangeable projection of that tree.

A `Node` looks rather like a SwiftUI `View`. However, rather than describing UI in a `body`,
it declares its persistent state, children, dependencies, and behavior through a declarative `rules` result builder.

```swift
import StateTree

struct Counter: Node, Identifiable {
  let id: Int
  let shouldDelete: () -> Void

  @Value var count: Int = 0          // observable, persisted state

  var rules: some Rules {
    OnUpdate(count) { _ in           // declarative lifecycle reaction
      count = max(min(10, count), -10)
    }
  }

  func increment() { count += 1 }
  func decrement() { count -= 1 }
  func delete()    { shouldDelete() }
}
```

Parent nodes compose their children declaratively by routing over data, so the
shape of the tree follows from state rather than from imperative wiring:

```swift
struct CountersList: Node {
  @Value private var counterIDs: [Int] = []
  @Route var counters: [Counter] = []

  var rules: some Rules {
    Serve(data: counterIDs, at: $counters) { id in
      Counter(id: id, shouldDelete: { delete(counter: id) })
    }
  }
}
```

A `Tree<RootNode>` runtime hosts the root node, propagates changes through a
priority-queue update engine, and exposes the resulting state in serializable
form.

## Core concepts

| Concept | What it is |
| --- | --- |
| **`Node`** | A value-type (`struct`) unit of domain state and behavior. Declares a `rules` builder. |
| **`@Value`** | Observable, persisted state held in the runtime — the source of truth. |
| **`@Route`** | Declares child node(s) and gives the tree its structure. Single, list, and 2/3-way union routers are supported. |
| **`@Projection`** | A two-way passthrough into state owned elsewhere in the tree. Equivalent to SwiftUI's `@Binding`. |
| **`@Dependency`** | Environment-style dependency injection, resolved down the tree. |
| **`@Scope`** | Access to the runtime for transactions and structural operations. |
| **Rules** | A `@RuleBuilder` DSL: routing (`Serve`), lifecycle (`OnStart`, `OnStop`, `OnUpdate`, `OnChange`, `OnReceive`), intents (`OnIntent`), and `Inject`. |
| **Behaviors** | Managed, trackable side effects (sync, async, or streamed) with interceptors — awaitable and mockable in tests. |
| **Intents** | URL-encodable, resumable, multi-step actions that flow down the tree to drive navigation and deep linking. |

## What the separation provides

- **UI independence.** The same domain tree can drive SwiftUI, UIKit, AppKit, a
  test harness, or a headless process. The interface can be replaced or omitted.
- **Whole-app serialization.** The runtime reduces the live tree to a `Codable`
  `TreeStateRecord`. State can be captured as JSON, persisted, and used to start
  the application from a saved point (`tree.start(from:)`).
- **Time-travel debugging.** `StateTreePlayback` records and replays state frames
  (`Recorder`, `Player`, `StateFrame`), with a SwiftUI `PlaybackView` provided.
- **Testable side effects.** Behaviors are tracked and interceptable, which makes
  asynchronous work deterministic and awaitable in tests.
- **Deep-linkable navigation.** Intents are URL-encoded and resolved step by step
  by the nodes along a route.
- **Structured concurrency.** All tree access is isolated to the `@TreeActor`
  global actor — aliased to `@MainActor` by default and replaceable with a custom
  actor — with Swift's strict concurrency checking enabled.

## Packages

| Module | Purpose |
| --- | --- |
| `StateTree` | The core runtime, nodes, fields, rules, routing, and serialization. |
| `StateTreeSwiftUI` | SwiftUI bridge: `@TreeRoot`, `@TreeNode`, projections to `Binding`s, `PlaybackView`. |
| `StateTreeImperativeUI` | Bridge for imperative UIKit and AppKit hosts. |
| `StateTreePlayback` | Recording and replay of tree state for time-travel debugging. |
| `StateTreeTesting` | Test utilities for driving and asserting on trees. |

In SwiftUI, the tree is mounted with a single property wrapper, and nodes are
exposed to views as observable values with `Binding` projections:

```swift
@main
struct CounterApp: App {
  @TreeRoot var root = CountersList()

  var body: some Scene {
    WindowGroup { CountersListView(list: $root.node) }
  }
}

struct CounterView: View {
  @TreeNode var counter: Counter

  var body: some View {
    Stepper("\(counter.count)",
            onIncrement: counter.increment,
            onDecrement: counter.decrement)
  }
}
```

## Requirements 

- Swift 5.8+ toolchain, with concurrency upcoming-features enabled.
- **macOS 12.3+ / iOS 15.4+** for the SwiftUI module.
- SwiftUI is optional. The core builds without it — on Linux, for example — and
  the SwiftUI targets are excluded automatically in that case.

The package depends on
[swift-collections](https://github.com/apple/swift-collections) and on two
internal libraries under `Vendor/`: `Emitter` (reactive streams) and `Disposable`
(lifetime management).

## Examples

The `Examples/` directory contains three complete apps that share their domain
logic across different UI styles:

- **Counter** — a UIKit/AppKit app built on `StateTreeImperativeUI`.
- **ToDo** — a SwiftUI app using `NavigationSplitView`, routed selection, and
  state booted from a bundled JSON snapshot.
- **TicTacToe** — game logic modelled as a node tree.

## Status

StateTree is complete. It reached its goals on **2023-06-08** with `v0.1.0` — by
coincidence the same week `@Observable` was introduced at WWDC 2023.

It is preserved as a research artifact, not maintained as a production dependency.
Were the work continued in Swift, its foundations would be rebuilt on what the language
and SDK have since provided: `@Observable` and the Observation framework, and the now-mature
concurrency and macro features.

On **2026-06-03** the project was updated the project to build and
run under the Swift 6.3 toolchain.

## License

MIT © 2023 GOOD HATS LLC (Adam Zethraeus). See [LICENSE](./LICENSE).
