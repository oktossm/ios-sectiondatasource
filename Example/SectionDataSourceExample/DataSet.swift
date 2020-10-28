import Foundation
import SectionDataSource


extension Int: Diffable {}


struct RandomContent: Diffable, Equatable {
    let differenceIdentifier: Int
    let content = Bool.random()

    init(_ int: Int) {
        self.differenceIdentifier = int
    }
}


struct DataSet {
    static func generateItems() -> [Int] {
        let count = Int.random(in: 0..<80) + 20
        let items = Array(0..<count)
        return items.shuffled()
    }

    static func generateSortItems() -> [Int] {
        let count = Int.random(in: 0..<150) + 50
        let items = Array(0..<count)
        return items.filter { _ in Bool.random() }
    }

    static func generateRandomlyEquatableItems() -> [RandomContent] {
        let count = Int.random(in: 0..<150) + 50
        let items = Array(0..<count)
        return items.filter { _ in Bool.random() }.map { _ in RandomContent(Int.random(in: 0..<200)) }
    }
}
