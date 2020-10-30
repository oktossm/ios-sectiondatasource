//
// Created by Mikhail Mulyar on 08/09/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import Foundation
import UIKit


public extension UITableView {

    func reload(using orderedChangeSteps: OrderedChangeSteps, with animation: @autoclosure () -> RowAnimation) {
        while let changeStep = orderedChangeSteps.nextStep() {
            self.reload(using: changeStep, with: animation())
        }
    }

    func reload(using orderedChangeSteps: OrderedChangeSteps,
                deleteSectionsAnimation: @autoclosure () -> RowAnimation,
                insertSectionsAnimation: @autoclosure () -> RowAnimation,
                reloadSectionsAnimation: @autoclosure () -> RowAnimation,
                deleteRowsAnimation: @autoclosure () -> RowAnimation,
                insertRowsAnimation: @autoclosure () -> RowAnimation,
                reloadRowsAnimation: @autoclosure () -> RowAnimation) {
        while let changeStep = orderedChangeSteps.nextStep() {
            self.reload(using: changeStep,
                        deleteSectionsAnimation: deleteSectionsAnimation(),
                        insertSectionsAnimation: insertSectionsAnimation(),
                        reloadSectionsAnimation: reloadSectionsAnimation(),
                        deleteRowsAnimation: deleteRowsAnimation(),
                        insertRowsAnimation: insertRowsAnimation(),
                        reloadRowsAnimation: reloadRowsAnimation())
        }
    }

    func reload(using changeStep: ChangeStep, with animation: @autoclosure () -> RowAnimation) {
        reload(using: changeStep,
               deleteSectionsAnimation: animation(),
               insertSectionsAnimation: animation(),
               reloadSectionsAnimation: animation(),
               deleteRowsAnimation: animation(),
               insertRowsAnimation: animation(),
               reloadRowsAnimation: animation())
    }

    func reload(using changeStep: ChangeStep,
                deleteSectionsAnimation: @autoclosure () -> RowAnimation,
                insertSectionsAnimation: @autoclosure () -> RowAnimation,
                reloadSectionsAnimation: @autoclosure () -> RowAnimation,
                deleteRowsAnimation: @autoclosure () -> RowAnimation,
                insertRowsAnimation: @autoclosure () -> RowAnimation,
                reloadRowsAnimation: @autoclosure () -> RowAnimation) {

        if case .none = window {
            return reloadData()
        }

        _performBatchUpdates {

            if !changeStep.sectionDeleted.isEmpty {
                deleteSections(IndexSet(changeStep.sectionDeleted), with: deleteSectionsAnimation())
            }

            if !changeStep.sectionInserted.isEmpty {
                insertSections(IndexSet(changeStep.sectionInserted), with: insertSectionsAnimation())
            }

            if !changeStep.sectionUpdated.isEmpty {
                reloadSections(IndexSet(changeStep.sectionUpdated), with: reloadSectionsAnimation())
            }

            for (source, target) in changeStep.sectionMoved {
                moveSection(source, toSection: target)
            }

            if !changeStep.elementDeleted.isEmpty {
                deleteRows(at: changeStep.elementDeleted, with: deleteRowsAnimation())
            }

            if !changeStep.elementInserted.isEmpty {
                insertRows(at: changeStep.elementInserted, with: insertRowsAnimation())
            }

            if !changeStep.elementUpdated.isEmpty {
                if let customElementUpdate = changeStep.customElementUpdate {
                    customElementUpdate(changeStep)
                } else {
                    reloadRows(at: changeStep.elementUpdated, with: reloadRowsAnimation())
                }
            }

            for (source, target) in changeStep.elementMoved {
                moveRow(at: source, to: target)
            }
        }
    }

    private func _performBatchUpdates(_ updates: () -> Void) {
        if #available(iOS 11.0, tvOS 11.0, *) {
            performBatchUpdates(updates)
        } else {
            beginUpdates()
            updates()
            endUpdates()
        }
    }
}


public extension UICollectionView {

    func reload(using orderedChangeSteps: OrderedChangeSteps) {
        let steps = orderedChangeSteps
        while let changeStep = steps.nextStep() {
            self.reload(using: changeStep)
        }
    }

    func reload(using changeStep: ChangeStep) {
        if case .none = window {
            return reloadData()
        }

        performBatchUpdates({
            if !changeStep.sectionDeleted.isEmpty {
                deleteSections(IndexSet(changeStep.sectionDeleted))
            }

            if !changeStep.sectionInserted.isEmpty {
                insertSections(IndexSet(changeStep.sectionInserted))
            }

            if !changeStep.sectionUpdated.isEmpty {
                reloadSections(IndexSet(changeStep.sectionUpdated))
            }

            for (source, target) in changeStep.sectionMoved {
                moveSection(source, toSection: target)
            }

            if !changeStep.elementDeleted.isEmpty {
                deleteItems(at: changeStep.elementDeleted)
            }

            if !changeStep.elementInserted.isEmpty {
                insertItems(at: changeStep.elementInserted)
            }

            if !changeStep.elementUpdated.isEmpty {
                if let customElementUpdate = changeStep.customElementUpdate {
                    customElementUpdate(changeStep)
                } else {
                    reloadItems(at: changeStep.elementUpdated)
                }
            }

            for (source, target) in changeStep.elementMoved {
                moveItem(at: source, to: target)
            }
        })
    }
}
