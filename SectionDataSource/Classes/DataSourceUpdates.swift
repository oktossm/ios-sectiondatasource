//
// Created by Mikhail Mulyar on 25/08/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import PHDiff


public enum Direction {
    case up
    case down
}


public struct ArrayDiff {

    public typealias Move = (fromIndex: Int, toIndex: Int)
    public typealias Update = (newIndex: Int, oldIndex: Int)

    public let inserts: [Int]
    public let deletes: [Int]
    public let moves: [Move]
    public let updates: [Update]

    public var isEmpty: Bool {
        return inserts.isEmpty && deletes.isEmpty && updates.isEmpty && moves.isEmpty
    }

    public init() {
        self.inserts = [Int]()
        self.deletes = [Int]()
        self.moves = [Move]()
        self.updates = [Update]()
    }

    public init(inserts: [Int] = [], deletes: [Int] = [], moves: [Move] = [], updates: [Update] = []) {
        self.inserts = inserts
        self.deletes = deletes
        self.moves = moves
        self.updates = updates
    }

    public init<T>(diffSteps: [DiffStep<T>]) {

        var i = [Int]()
        var d = [Int]()
        var m = [Move]()
        var u = [Update]()

        diffSteps.forEach {
            switch $0 {
            case let .insert(_, index):
                i.append(index)
            case let .delete(_, index):
                d.append(index)
            case let .move(_, old, index):
                m.append((old, index))
            case let .update(_, index, old):
                u.append((index, old))
            }
        }

        self.inserts = i
        self.deletes = d
        self.moves = m
        self.updates = u
    }

    public func insertedPaths(in section: Int = 0) -> [IndexPath] {
        return self.inserts.map { IndexPath(row: $0, section: section) }
    }

    public func deletedPaths(in section: Int = 0) -> [IndexPath] {
        return self.deletes.map { IndexPath(row: $0, section: section) }
    }

    public func movedPaths(in section: Int = 0) -> [(IndexPath, IndexPath)] {
        return self.moves.map { (IndexPath(row: $0.fromIndex, section: section), IndexPath(row: $0.toIndex, section: section)) }
    }

    public func updatedPaths(in section: Int = 0) -> [IndexPath] {
        return self.updates.map { IndexPath(row: $0.oldIndex, section: section) }
    }

    //Should be applied in order: deletions, insertions, updates
    public typealias SortedDiff = (deletions: [Int], insertions: [Int], updates: [Update])
    public typealias SortedPaths = (deletions: [IndexPath], insertions: [IndexPath], updates: [IndexPath])

    public func sortedDiff() -> SortedDiff {
        var insertions: [Int] = self.inserts
        let updates: [Update] = self.updates
        var indexedDeletions = [Int: Int]()

        self.deletes.forEach { indexedDeletions[$0] = ($0) }
        self.moves.forEach {
            insertions.append($0.1)
            indexedDeletions[$0.0] = ($0.0)
        }

        // Insertions need to be sorted asc, batchUpdates already does that.
        insertions.sort { $0 < $1 }

        // Deletions need to be sorted desc.
        let deletions = Array(indexedDeletions.values.reversed())

        return (deletions, insertions, updates)
    }

    public func sortedPaths(in section: Int = 0) -> SortedPaths {
        let sortedDiff = self.sortedDiff()
        let deletions = sortedDiff.deletions.map { IndexPath(row: $0, section: section) }
        let insertions = sortedDiff.insertions.map { IndexPath(row: $0, section: section) }
        let updates = sortedDiff.updates.map { IndexPath(row: $0.oldIndex, section: section) }

        return (deletions, insertions, updates)
    }
}


public protocol DiffSectionType: Diffable {
    associatedtype Item: Diffable
    var diffIdentifier: String { get }
    var items: [Item] { get }
}


func ==<T: DiffSectionType>(lhs: T, rhs: T) -> Bool {
    return false
}


public struct NestedDiff {
    public let sectionsDiffSteps: ArrayDiff
    public let itemsDiffSteps: [ArrayDiff]    // New section indexes
    public let oldItemDiffSteps: [ArrayDiff]  // Old section indexes (used in tableView/collectionView batch updates)

    public init(sectionsDiffSteps: ArrayDiff, itemsDiffSteps: [ArrayDiff], oldItemDiffSteps: [ArrayDiff]) {
        self.sectionsDiffSteps = sectionsDiffSteps
        self.itemsDiffSteps = itemsDiffSteps
        self.oldItemDiffSteps = oldItemDiffSteps
    }
}


extension Array where Element: DiffSectionType {

    public func nestedDifference(from array: [Element]) -> NestedDiff {

        var itemsSteps: [ArrayDiff] = []
        var oldItemsSteps: [ArrayDiff] = []
        self.forEach { _ in itemsSteps.append(ArrayDiff()) }
        array.forEach { _ in oldItemsSteps.append(ArrayDiff()) }

        let steps = self.difference(from: array).compactMap {
            (step: DiffStep<Element>) -> DiffStep<Element>? in
            switch step {
            case let .move(section, oldIndex, index):
                let old = array[oldIndex]

                let diff: [DiffStep<Element.Item>] = section.items.difference(from: old.items)
                itemsSteps[index] = ArrayDiff(diffSteps: diff)
                oldItemsSteps[oldIndex] = ArrayDiff(diffSteps: diff)
                return step
            case let .update(section, index, oldIndex):
                let old = array[oldIndex]

                let diff: [DiffStep<Element.Item>] = section.items.difference(from: old.items)
                itemsSteps[index] = ArrayDiff(diffSteps: diff)
                oldItemsSteps[oldIndex] = ArrayDiff(diffSteps: diff)
                return nil
            default:
                return step
            }
        }

        return NestedDiff(sectionsDiffSteps: ArrayDiff(diffSteps: steps), itemsDiffSteps: itemsSteps, oldItemDiffSteps: itemsSteps)
    }
}


public enum DataSourceUpdates {
    case reload
    case initial(changes: NestedDiff)
    case update(changes: ArrayDiff)
    case updateSections(changes: NestedDiff)
    case pagination(changes: ArrayDiff, direction: Direction) //Not used currentlyb
    case countReduction(changes: ArrayDiff, direction: Direction) //Not used currently
}


//MARK: - UIKit
extension ArrayDiff {
    func update(tableView: UITableView, animations: UITableView.RowAnimation = .fade, performReloads: Bool = true) {
        let sorted = self.sortedPaths()

        if sorted.deletions.isEmpty == false {
            tableView.deleteRows(at: sorted.deletions, with: animations)
        }
        if sorted.insertions.isEmpty == false {
            tableView.insertRows(at: sorted.insertions, with: animations)
        }
        if sorted.updates.isEmpty == false, performReloads == true {
            tableView.reloadRows(at: sorted.updates, with: animations)
        }
    }

    func update(collectionView: UICollectionView, performReloads: Bool = true) {
        let sorted = self.sortedPaths()

        if sorted.deletions.isEmpty == false {
            collectionView.deleteItems(at: sorted.deletions)
        }
        if sorted.insertions.isEmpty == false {
            collectionView.insertItems(at: sorted.insertions)
        }
        if sorted.updates.isEmpty == false, performReloads == true {
            collectionView.reloadItems(at: sorted.updates)
        }
    }
}


extension NestedDiff {
    func update(tableView: UITableView, animations: UITableView.RowAnimation = .fade, performReloads: Bool = true) {
        let sorted = self.sectionsDiffSteps.sortedDiff()

        if sorted.deletions.isEmpty == false {
            tableView.deleteSections(IndexSet(sorted.deletions), with: animations)
        }
        if sorted.insertions.isEmpty == false {
            tableView.insertSections(IndexSet(sorted.insertions), with: animations)
        }
        if sorted.updates.isEmpty == false {
            tableView.reloadSections(IndexSet(sorted.updates.map { $0.oldIndex }), with: animations)
        }

        for (index, diff) in self.oldItemDiffSteps.filter({ !$0.isEmpty }).enumerated() {
            let sorted = diff.sortedPaths(in: index)

            if sorted.deletions.isEmpty == false {
                tableView.deleteRows(at: sorted.deletions, with: animations)
            }
            if sorted.insertions.isEmpty == false {
                tableView.insertRows(at: sorted.insertions, with: animations)
            }
            if sorted.updates.isEmpty == false, performReloads == true {
                tableView.reloadRows(at: sorted.updates, with: animations)
            }
        }
    }

    func update(collectionView: UICollectionView, performReloads: Bool = true) {
        let sorted = self.sectionsDiffSteps.sortedDiff()

        if sorted.deletions.isEmpty == false {
            collectionView.deleteSections(IndexSet(sorted.deletions))
        }
        if sorted.insertions.isEmpty == false {
            collectionView.insertSections(IndexSet(sorted.insertions))
        }
        if sorted.updates.isEmpty == false {
            collectionView.reloadSections(IndexSet(sorted.updates.map { $0.oldIndex }))
        }

        for (index, diff) in self.oldItemDiffSteps.filter({ !$0.isEmpty }).enumerated() {
            let sorted = diff.sortedPaths(in: index)

            if sorted.deletions.isEmpty == false {
                collectionView.deleteItems(at: sorted.deletions)
            }
            if sorted.insertions.isEmpty == false {
                collectionView.insertItems(at: sorted.insertions)
            }
            if sorted.updates.isEmpty == false, performReloads == true {
                collectionView.reloadItems(at: sorted.updates)
            }
        }
    }
}
