import Emitter
import Foundation
import TreeActor

@_spi(Implementation) import Utilities

// MARK: - BehaviorEvent

public enum BehaviorEvent: Codable, CustomStringConvertible {
  public var description: String {
    switch self {
    case .created(let behaviorID):
      return "created behavior (id: \(behaviorID))"
    case .started(let behaviorID):
      return "started behavior (id: \(behaviorID))"
    case .finished(let behaviorID):
      return "finished behavior (id: \(behaviorID))"
    }
  }

  public var behaviorID: BehaviorID {
    switch self {
    case .created(let behaviorID):
      return behaviorID
    case .started(let behaviorID):
      return behaviorID
    case .finished(let behaviorID):
      return behaviorID
    }
  }

  case created(BehaviorID)
  case started(BehaviorID)
  case finished(BehaviorID)
}

// MARK: - BehaviorTracker

public final class BehaviorTracker {

  // MARK: Lifecycle

  public init(
    tracking: Tracking = .defaults,
    behaviorInterceptors: [BehaviorInterceptor] = []
  ) {
    self.tracking = tracking
    let index = behaviorInterceptors.indexed(by: \.id)
    self.behaviorInterceptors = index
    assert(
      behaviorInterceptors.count == index.count,
      "multiple interceptors can not be registered for the same behavior id."
    )
  }

  // MARK: Public

  /// Whether to track ``Behavior`` instances created during the runtime.
  /// ``BehaviorTrackingConfig/track`` is required to enable `await`ing
  /// ``TreeLifetime/behaviorResolutions`` in unit tests.
  public enum Tracking {

    public static var defaults: Tracking {
      #if DEBUG
      .indefinitely
      #else
      .untilComplete
      #endif
    }

    /// Track ``Behavior`` instances until they have completed or cancelled.
    ///
    /// This allows testing code to `await` all inflight behaviors before making
    /// assertions.
    case untilComplete

    /// Track ``Behavior`` instances indefinitely
    ///
    /// This allows testing code to inspect finished behavior resolutions.
    case indefinitely
  }

  public var behaviors: [Behaviors.Resolution] {
    trackedBehaviors.withLock { $0 }.map { $0 }
  }

  @_spi(Implementation) public var behaviorEvents: some Emitter<BehaviorEvent, Never> {
    behaviorEventSubject
  }

  public var behaviorResolutions: [Behaviors.Result] {
    get async {
      var resolutions: [Behaviors.Result] = []
      let behaviors = trackedBehaviors.withLock { $0 }
      for behavior in behaviors {
        let resolution = await behavior.value
        resolutions.append(resolution)
      }
      return resolutions
    }
  }

  public func awaitReady(timeoutSeconds: Double? = nil) async throws {
    let behaviors = trackedBehaviors.withLock { $0 }
    if behaviors.isEmpty {
      runtimeWarning("there are no registered behaviors to await")
    }
    let action = {
      for behavior in behaviors {
        await behavior.awaitReady()
      }
    }
    if let timeoutSeconds {
      try await Async.timeout(seconds: timeoutSeconds) {
        await action()
      }.get()
    } else {
      await action()
    }
  }

  public func awaitBehaviors(timeoutSeconds: Double? = nil) async throws {
    let behaviors = trackedBehaviors.withLock { $0 }
    if behaviors.isEmpty {
      runtimeWarning("there are no registered behaviors to await")
    }
    if let timeoutSeconds {
      try await Async.timeout(seconds: timeoutSeconds) {
        _ = await self.behaviorResolutions
      }.get()
    } else {
      _ = await behaviorResolutions
    }
  }

  // MARK: Internal

  nonisolated func intercept<B: BehaviorType>(
    behavior: inout B,
    input: B.Input
  ) {
    behaviorInterceptors[behavior.id]?.intercept(behavior: &behavior, input: input)
  }

  nonisolated func trackCreate(
    resolution: Behaviors.Resolution
  ) -> (started: @Sendable () -> Void, finished: @Sendable () -> Void) {
    trackedBehaviors
      .withLock { $0.insert(resolution) }
    behaviorEventSubject.emit(value: .created(resolution.id))

    return (
      started: { [behaviorEventSubject] in
        behaviorEventSubject.emit(value: .started(resolution.id))
      },
      finished: { [behaviorEventSubject, tracking] in
        if tracking == .untilComplete {
          self.trackedBehaviors
            .withLock { $0.remove(resolution) }
        }
        behaviorEventSubject.emit(value: .finished(resolution.id))
      }
    )
  }

  // MARK: Private

  private let behaviorEventSubject = PublishSubject<BehaviorEvent, Never>()

  private let behaviorInterceptors: [BehaviorID: BehaviorInterceptor]
  private var trackedBehaviors: Locked<Set<Behaviors.Resolution>> = .init([])
  private let tracking: Tracking
}

extension BehaviorTracker {

  public nonisolated func behaviorResolutions(timeoutSeconds: Double? = nil) async throws
    -> [Behaviors.Result]
  {
    guard let timeoutSeconds
    else {
      return await behaviorResolutions
    }
    return try await Async.timeout(seconds: timeoutSeconds) {
      await self.behaviorResolutions
    }.get()
  }
}
