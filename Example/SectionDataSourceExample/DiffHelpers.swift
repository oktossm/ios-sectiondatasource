//
// Created by Mikhail Mulyar on 23/11/2017.
// Copyright (c) 2017 Mikhail Mulyar. All rights reserved.
//

import SectionDataSource


// MARK: - UIKit
extension ArrayDiff {
    func update(tableView: UITableView, animations: UITableView.RowAnimation = .fade, performReloads: Bool = true) {
        let deleted = self.deletedPaths()
        let inserted = self.insertedPaths()
        let moved = self.movedPaths()
        let updated = self.updatedPaths()
        if deleted.isEmpty == false {
            tableView.deleteRows(at: deleted, with: animations)
        }
        if inserted.isEmpty == false {
            tableView.insertRows(at: inserted, with: animations)
        }
        if moved.isEmpty == false {
            moved.forEach { tableView.moveRow(at: $0.0, to: $0.1) }
        }
        if updated.isEmpty == false, performReloads == true {
            tableView.reloadRows(at: updated, with: animations)
        }
    }

    func update(collectionView: UICollectionView, performReloads: Bool = true) {
        let deleted = self.deletedPaths()
        let inserted = self.insertedPaths()
        let moved = self.movedPaths()
        let updated = self.updatedPaths()
        if deleted.isEmpty == false {
            collectionView.deleteItems(at: deleted)
        }
        if inserted.isEmpty == false {
            collectionView.insertItems(at: inserted)
        }
        if moved.isEmpty == false {
            moved.forEach { collectionView.moveItem(at: $0.0, to: $0.1) }
        }
        if updated.isEmpty == false, performReloads == true {
            collectionView.reloadItems(at: updated)
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
        for (index, diff) in self.itemsDiffSteps.filter({ !$0.isEmpty }).enumerated() {
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
        for (index, diff) in self.itemsDiffSteps.filter({ !$0.isEmpty }).enumerated() {
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
