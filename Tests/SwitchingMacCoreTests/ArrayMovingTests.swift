import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("並び替えユーティリティ")
struct ArrayMovingTests {
    private let items = ["A", "B", "C", "D"]

    @Test("要素を後方へ移動する")
    func moveDown() {
        let moved = items.movingElements(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(moved == ["B", "C", "A", "D"])
    }

    @Test("要素を前方へ移動する")
    func moveUp() {
        let moved = items.movingElements(fromOffsets: IndexSet(integer: 3), toOffset: 0)

        #expect(moved == ["D", "A", "B", "C"])
    }

    @Test("複数要素をまとめて移動する")
    func moveMultiple() {
        let moved = items.movingElements(fromOffsets: IndexSet([0, 1]), toOffset: 4)

        #expect(moved == ["C", "D", "A", "B"])
    }

    @Test("同じ位置へ移動しても並びは変わらない")
    func moveToSamePosition() {
        let moved = items.movingElements(fromOffsets: IndexSet(integer: 1), toOffset: 1)

        #expect(moved == items)
    }

    @Test("範囲を超える移動先は末尾に丸められる")
    func clampsDestination() {
        let moved = items.movingElements(fromOffsets: IndexSet(integer: 0), toOffset: 99)

        #expect(moved == ["B", "C", "D", "A"])
    }
}
