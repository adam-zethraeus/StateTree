import Disposable
import StateTree
import XCTest

// MARK: - Union2RouterTests

final class Union2RouterTests: XCTestCase {

  let stage = DisposableStage()

  override func setUp() { }
  override func tearDown() {
    stage.reset()
  }

  @TreeActor
  func test_simple_defaultRoute() async throws {
    let tree = Tree(root: TestPlainDefault())
    let root = try tree.start()
    root
      .autostop()
      .stage(on: stage)
    XCTAssertEqual(try tree.assume.info.nodeCount, 2)
    XCTAssertNotNil(root.node.child.a)
  }

  @TreeActor
  func test_defaultRoute() async throws {
    let tree = Tree(root: TestRoot())
    let root = try tree.start()
    root
      .autostop()
      .stage(on: stage)
    XCTAssertEqual(try tree.assume.info.nodeCount, 2)
    XCTAssertNotNil(root.node.child.a)
  }

  @TreeActor
  func test_ruleRoute() async throws {
    let tree = Tree(root: TestRoot())
    let root = try tree.start()
    root
      .autostop()
      .stage(on: stage)
    let update0 = try tree.assume.info.flushUpdateStats().counts
    XCTAssertEqual(update0.nodeStops, 0)
    XCTAssertEqual(update0.nodeStarts, 2)
    XCTAssertEqual(update0.nodeUpdates, 2)
    XCTAssertNotNil(root.node.child.a)
    XCTAssertNil(root.node.child.b)

    root.node.routeCase = .aRoute
    let update1 = try tree.assume.info.flushUpdateStats().counts
    XCTAssertEqual(update1.nodeStops, 1)
    XCTAssertEqual(update1.nodeStarts, 1)
    XCTAssertEqual(update1.nodeUpdates, 2)
    XCTAssertEqual(try tree.assume.info.nodeCount, 2)
    XCTAssertNotNil(root.node.child.a)
    XCTAssertNil(root.node.child.b)

    root.node.routeCase = .bRoute
    let update2 = try tree.assume.info.flushUpdateStats().counts
    XCTAssertEqual(update2.nodeStops, 1)
    XCTAssertEqual(update2.nodeStarts, 1)
    XCTAssertEqual(update2.nodeUpdates, 2)
    XCTAssertEqual(try tree.assume.info.nodeCount, 2)
    XCTAssertNotNil(root.node.child.b)
    XCTAssertNil(root.node.child.a)

    root.node.routeCase = .defaultRoute
    let update3 = try tree.assume.info.flushUpdateStats().counts
    XCTAssertEqual(update3.nodeStops, 1)
    XCTAssertEqual(update3.nodeStarts, 1)
    XCTAssertEqual(update3.nodeUpdates, 2)
    XCTAssertEqual(try tree.assume.info.nodeCount, 2)
    XCTAssertNotNil(root.node.child.a)
    XCTAssertNil(root.node.child.b)
  }
}

// MARK: Union2RouterTests.TestDefault

extension Union2RouterTests {

  struct ChildA: Node {
    var rules: some Rules { () }
  }

  struct ChildB: Node {
    var rules: some Rules { () }
  }

  struct TestPlainDefault: Node {

    @Route var child: Union.Two<ChildA, ChildB> = .a(ChildA())

    var rules: some Rules {
      ()
    }
  }

  struct TestRoot: Node {
    enum RouteCase: TreeState {
      case defaultRoute
      case aRoute
      case bRoute
    }

    @Route var child: Union.Two<ChildA, ChildB> = .a(ChildA())
    @Value var routeCase: RouteCase = .defaultRoute

    var rules: some Rules {
      if routeCase == .aRoute {
        Serve(.a(ChildA()), at: $child)
      } else if routeCase == .bRoute {
        Serve(.b(ChildB()), at: $child)
      }
    }
  }

}
