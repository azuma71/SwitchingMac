import Foundation

extension Array {
    /// SwiftUI の `onMove` と同じ規則で要素を移動した新しい配列を返す。
    ///
    /// - Parameters:
    ///   - source: 移動する要素の位置
    ///   - destination: 移動前の配列における挿入位置
    func movingElements(fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
        let movedElements = source.map { self[$0] }
        var remaining = self
        for index in source.sorted(by: >) {
            remaining.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = Swift.min(
            Swift.max(destination - removedBeforeDestination, 0),
            remaining.count
        )
        remaining.insert(contentsOf: movedElements, at: insertionIndex)
        return remaining
    }
}
