@_spi(Implementation) import StateTree
import Utilities

// MARK: - RouterAccess

@dynamicMemberLookup
@TreeActor
public protocol RouterAccess {
  associatedtype NodeType: Node
  associatedtype Accessor: ScopeAccess where Accessor.NodeType == NodeType
  @_spi(Implementation) var access: Accessor { get }
}

extension RouterAccess {
  public subscript<SubNode: Node>(
    dynamicMember dynamicMember: KeyPath<NodeType, Route<SingleRouter<SubNode>>>
  ) -> Reported<SubNode> {
    try! Reported(scope: access.access(via: dynamicMember))
  }

  public subscript<SubNode: Node>(
    dynamicMember dynamicMember: KeyPath<NodeType, Route<MaybeSingleRouter<SubNode>>>
  ) -> Reported<SubNode>? {
    try! access.access(via: dynamicMember).map { Reported(scope: $0) }
  }

  public subscript<SubNodeA: Node, SubNodeB: Node>(
    dynamicMember dynamicMember: KeyPath<NodeType, Route<Union2Router<SubNodeA, SubNodeB>>>
  ) -> Union.Two<Reported<SubNodeA>, Reported<SubNodeB>> {
    try! access.access(via: dynamicMember)
      .map(
        a: { Reported(scope: $0) },
        b: { Reported(scope: $0) }
      )
  }

  public subscript<SubNodeA: Node, SubNodeB: Node>(
    dynamicMember dynamicMember: KeyPath<NodeType, Route<MaybeUnion2Router<SubNodeA, SubNodeB>>>
  ) -> Union.Two<Reported<SubNodeA>, Reported<SubNodeB>>? {
    try! access.access(via: dynamicMember)?
      .map(
        a: { Reported(scope: $0) },
        b: { Reported(scope: $0) }
      )
  }

  public subscript<SubNodeA: Node, SubNodeB: Node, SubNodeC: Node>(
    dynamicMember dynamicMember: KeyPath<
      NodeType,
      Route<Union3Router<SubNodeA, SubNodeB, SubNodeC>>
    >
  ) -> Union.Three<Reported<SubNodeA>, Reported<SubNodeB>, Reported<SubNodeC>> {
    try! access.access(via: dynamicMember)
      .map(
        a: { Reported(scope: $0) },
        b: { Reported(scope: $0) },
        c: { Reported(scope: $0) }
      )
  }

  public subscript<SubNodeA: Node, SubNodeB: Node, SubNodeC: Node>(
    dynamicMember dynamicMember: KeyPath<
      NodeType,
      Route<MaybeUnion3Router<SubNodeA, SubNodeB, SubNodeC>>
    >
  ) -> Union.Three<Reported<SubNodeA>, Reported<SubNodeB>, Reported<SubNodeC>>? {
    try! access.access(via: dynamicMember)?
      .map(
        a: { Reported(scope: $0) },
        b: { Reported(scope: $0) },
        c: { Reported(scope: $0) }
      )
  }

  public subscript<SubNode: Node>(
    dynamicMember dynamicMember: KeyPath<NodeType, Route<ListRouter<SubNode>>>
  ) -> DeferredList<Int, Reported<SubNode>, any Error> {
    let list = try! access.access(via: dynamicMember)
    return DeferredList(indices: list.startIndex ..< list.endIndex) { index in
      (try? list.element(at: index))
        .unwrappingResult()
        .map { scope in
          Reported(scope: scope)
        }
        .mapError { $0 }
    }
  }
}
