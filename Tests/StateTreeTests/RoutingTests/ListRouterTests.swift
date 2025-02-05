import Disposable
@_spi(Implementation) import StateTree
import XCTest

// MARK: - ListRouterTests

final class ListRouterTests: XCTestCase {

  let stage = DisposableStage()

  override func setUp() { }
  override func tearDown() {
    stage.reset()
  }

  @TreeActor
  func test_singleDefaultRoute() async throws {
    let tree = Tree(root: TestSingleDefault())
    let root = try tree.start()
    root
      .autostop()
      .stage(on: stage)
    XCTAssertEqual(try tree.assume.info.nodeCount, 2)
    XCTAssertEqual(root.node.children.count, 1)
  }

  @TreeActor
  func test_emptyDefaultRoute() async throws {
    let tree = Tree(root: TestEmptyDefault())
    let root = try tree.start()
    root
      .autostop()
      .stage(on: stage)
    XCTAssertEqual(try tree.assume.info.nodeCount, 1)
    XCTAssertEqual(root.node.children.count, 0)
  }

  @TreeActor
  func test_rulesRoute() async throws {
    NodeID.incrementForTesting()
      .stage(on: stage)
    let tree = Tree(root: TestRules())
    let root = try tree.start()
    root
      .autostop()
      .stage(on: stage)

    let update0 = try tree.assume.info.flushUpdateStats()
    XCTAssertEqual(try tree.assume.info.nodeCount, 1)
    XCTAssertEqual(root.node.children.count, 0)
    XCTAssertEqual(update0.counts.allNodeEvents, 2)
    XCTAssertEqual(update0.counts.nodeUpdates, 1)
    XCTAssertEqual(update0.counts.nodeStarts, 1)
    XCTAssertEqual(update0.counts.nodeStops, 0)

    root.node.ids = [0, 1, 2, 4, 5, 6]

    let update1 = try tree.assume.info.flushUpdateStats()
    XCTAssertEqual(try tree.assume.info.nodeCount, 7)
    XCTAssertEqual(root.node.children.count, 6)
    XCTAssertEqual(update1.counts.allNodeEvents, 13)
    XCTAssertEqual(update1.counts.nodeUpdates, 7)
    XCTAssertEqual(update1.counts.nodeStarts, 6)
    XCTAssertEqual(update1.counts.nodeStops, 0)

    root.node.children[0].state = "One"
    root.node.children[1].state = "Two"
    root.node.children[2].state = "Three"

    let update2 = try tree.assume.info.flushUpdateStats()
    XCTAssertEqual(try tree.assume.info.nodeCount, 7)
    XCTAssertEqual(root.node.children.count, 6)
    XCTAssertEqual(update2.counts.allNodeEvents, 3)
    XCTAssertEqual(update2.counts.nodeUpdates, 3)
    XCTAssertEqual(update2.counts.nodeStarts, 0)
    XCTAssertEqual(update2.counts.nodeStops, 0)
    XCTAssertEqual(root.node.children[0].state, "One")
    XCTAssertEqual(root.node.children[1].state, "Two")
    XCTAssertEqual(root.node.children[2].state, "Three")

    root.node.ids = [1]

    let update3 = try tree.assume.info.flushUpdateStats()
    XCTAssertEqual(try tree.assume.info.nodeCount, 2)
    XCTAssertEqual(root.node.children.count, 1)
    XCTAssertEqual(update3.counts.allNodeEvents, 6)
    XCTAssertEqual(update3.counts.nodeUpdates, 1)
    XCTAssertEqual(update3.counts.nodeStarts, 0)
    XCTAssertEqual(update3.counts.nodeStops, 5)
    XCTAssertEqual(root.node.children[0].state, "Two")

    root.node.ids = [0, 1, 2, 4, 5, 6]
    _ = try tree.assume.info.flushUpdateStats()
    root.node.other = "hi"
    root.node.ids = [0, 1, 2, 4, 5, 6]
    let unrelated = try tree.assume.info.flushUpdateStats()
    XCTAssertEqual(unrelated.counts.allNodeEvents, 1)

    root.node.ids = [2, 1]

    XCTAssertEqual(root.node.children[1].state, "Two")
    XCTAssertNil(root.node.children[0].state)
  }

  @TreeActor
  func test_removalRoute() async throws {
    let tree = Tree(
      root: ListNode()
    )
    try tree.start()
    let rootNode = try tree.assume.rootNode

    var sorted: [String] = []
    var nodes: [NodeA] = []

    func assertAfter(_ nums: [Int]) {
      sorted = nums.map { String($0) }
      rootNode.numbers = nums
      nodes = rootNode.route
      XCTAssertEqual(nodes.map(\.idStr), sorted)
    }

    assertAfter(Array(0 ..< 100))
    assertAfter(Array(0 ..< 20))
    assertAfter(Array(5 ..< 15))
    try tree.assume.rootNode.numbers = (Array(10 ..< 15) + Array(20 ..< 30))
    nodes = try XCTUnwrap(try tree.assume.rootNode.route)
    XCTAssertEqual(
      nodes.map(\.idStr),
      ["10", "11", "12", "13", "14", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29"]
    )
    XCTAssertEqual(nodes.count, 15)
    try tree.assume.rootNode.numbers! += Array(1000 ..< 2000)
    XCTAssertEqual(try tree.assume.rootNode.numbers?.count, 1015)
  }
}

extension ListRouterTests {

  // MARK: - ListNode

  struct ListNode: Node {
    @Value var numbers: [Int]? = nil
    @Route var route: [NodeA] = []
    var rules: some Rules {
      if let numbers {
        Serve(data: numbers, at: $route) { datum in
          NodeA(id: datum)
        }
      }
    }
  }

  // MARK: - NodeA

  struct NodeA: Node, Identifiable {
    let id: Int
    var idStr: String { String(id) }
    var rules: some Rules { .none }
  }

  struct ChildA: Node {
    @Value var state: String?
    var rules: some Rules { () }
  }

  struct TestSingleDefault: Node {
    @Route var children: [ChildA] = [ChildA()]
    var rules: some Rules {
      ()
    }
  }

  struct TestEmptyDefault: Node {
    @Route var children: [ChildA] = []
    var rules: some Rules {
      ()
    }
  }

  struct TestRules: Node {
    @Route var children: [ChildA] = []
    @Value var ids: [Int] = []
    @Value var other: String = ""
    var rules: some Rules {
      Serve(data: ids, at: $children) { _ in
        ChildA()
      }
    }
  }

}
