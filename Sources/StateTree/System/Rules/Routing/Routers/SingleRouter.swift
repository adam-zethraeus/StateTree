import TreeActor

// MARK: - SingleRouter

public struct SingleRouter<NodeType: Node>: RouterType {

  // MARK: Lifecycle

  init(builder: () -> NodeType) {
    self.capturedNode = builder()
  }

  // MARK: Public

  public typealias Value = NodeType

  public static var type: RouteType { .single }

  public let defaultRecord: RouteRecord = .single(.invalid)

  public var fallback: NodeType {
    capturedNode
  }

  @_spi(Implementation)
  @TreeActor
  public func current(at fieldID: FieldID, in runtime: Runtime) throws -> Value {
    guard
      let scope = try? runtime
        .getScopes(at: fieldID).first,
      let node = scope.node as? NodeType
    else {
      return capturedNode
    }
    return node
  }

  public mutating func assign(_ context: RouterRuleContext) {
    self.context = context
  }

  @_spi(Implementation)
  public mutating func syncToState(
    field fieldID: FieldID,
    in runtime: Runtime
  ) throws -> [AnyScope] {
    guard let context
    else {
      throw UnassignedRouterError()
    }
    hasApplied = true
    let record = runtime.getRouteRecord(at: fieldID)
    guard case .single(let singleRecord) = record
    else {
      assertionFailure()
      throw IncorrectRouterTypeError()
    }
    guard let record = runtime.getRecord(singleRecord)
    else {
      throw InvalidSyncFailure()
    }
    if (try? runtime.getScope(for: singleRecord)) != nil {
      return []
    }
    let capture = NodeCapture(capturedNode)
    let uninitialized = UninitializedNode(capture: capture, runtime: runtime)
    let initialized = try uninitialized.reinitializeNode(
      asType: NodeType.self,
      from: record,
      dependencies: context.dependencies,
      on: .init(fieldID: fieldID, identity: nil, type: .single, depth: context.depth)
    )
    return [try initialized.connect().erase()]
  }

  @_spi(Implementation)
  public mutating func apply(at fieldID: FieldID, in runtime: Runtime) throws {
    guard !hasApplied
    else {
      return
    }
    hasApplied = true

    guard let context
    else {
      throw UnassignedRouterError()
    }
    let capture = NodeCapture(capturedNode)
    let uninitialized = UninitializedNode(
      capture: capture,
      runtime: runtime
    )
    let initialized = try uninitialized.initializeNode(
      asType: NodeType.self,
      id: NodeID(),
      dependencies: context.dependencies,
      on: .init(
        fieldID: fieldID,
        identity: nil,
        type: .single,
        depth: context.depth
      )
    )
    let node = try initialized.connect()
    runtime.updateRouteRecord(
      at: fieldID,
      to: .single(node.nid)
    )
  }

  public mutating func update(from other: SingleRouter<NodeType>) {
    if
      let lhsID = capturedNode.identity,
      let rhsID = other.capturedNode.identity,
      lhsID != rhsID
    {
      self = other
    }
  }

  // MARK: Private

  private let capturedNode: NodeType
  private var hasApplied = false
  private var context: RouterRuleContext?

}

// MARK: - Route
extension Route {

  public init<NodeType: Node>(wrappedValue: @autoclosure () -> NodeType)
    where Router == SingleRouter<NodeType>
  {
    self.init(defaultRouter: SingleRouter(builder: wrappedValue))
  }
}

extension Serve {
  public init<Value>(_ node: Value, at route: Route<Router>) where Value: Node,
    Router == SingleRouter<Value>
  {
    self.init(router: Router(builder: { node }), at: route)
  }
}
