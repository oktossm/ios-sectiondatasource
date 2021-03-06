//
// Created by Mikhail Mulyar on 25/08/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import Foundation
import DifferenceKit


public class OrderedChangeSteps: CustomDebugStringConvertible {
    public private(set) var steps: ContiguousArray<ChangeStep>

    init(steps: ContiguousArray<ChangeStep>) {
        self.steps = steps
    }

    public func nextStep() -> ChangeStep? {
        guard !steps.isEmpty else { return nil }
        let step = steps.removeFirst()
        step.dataSourceUpdate()
        return step
    }

    // Forces data source update. You must call table/collection reloadData after forceUpdate().
    public func forceUpdate() {
        steps.last?.dataSourceUpdate()
        steps.removeAll()
    }

    public var debugDescription: String {
        String(describing: steps)
    }

    /// Closure for custom element updates. Called instead of reloading cells/rows if not nil
    public var customElementUpdate: ((ChangeStep) -> Void)? {
        set {
            for index in 0..<steps.count {
                steps[index].customElementUpdate = newValue
            }
        }
        get {
            steps.first?.customElementUpdate
        }
    }
}


public struct ChangeStep {
    var dataSourceUpdate: () -> Void

    /// Closure for custom element updates. Called instead of reloading cells/rows if not nil
    public var customElementUpdate: ((ChangeStep) -> Void)?

    /// The offsets of deleted sections.
    public var sectionDeleted: [Int]
    /// The offsets of inserted sections.
    public var sectionInserted: [Int]
    /// The offsets of updated sections.
    public var sectionUpdated: [Int]
    /// The pairs of source and target offset of moved sections.
    public var sectionMoved: [(source: Int, target: Int)]

    /// The paths of deleted elements.
    public var elementDeleted: [IndexPath]
    /// The paths of inserted elements.
    public var elementInserted: [IndexPath]
    /// The paths of updated elements.
    public var elementUpdated: [IndexPath]
    /// The pairs of source and target path of moved elements.
    public var elementMoved: [(source: IndexPath, target: IndexPath)]
}


public enum DataSourceUpdates {
    case reload
    case initial(changes: OrderedChangeSteps)
    case update(changes: OrderedChangeSteps)
}
