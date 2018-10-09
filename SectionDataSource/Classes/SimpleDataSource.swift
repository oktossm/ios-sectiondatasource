//
// Created by Mikhail Mulyar on 24/09/2017.
//

import PaulHeckelDifference


public class SimpleDataSource<Model: Diffable & Searchable>: SectionDataSource<Model> {

    public init(initialItems: [Model] = [Model](),
                sortType: SortType<Model>,
                filterType: FilterType<Model>? = nil,
                searchType: SearchType<Model> = .searchable,
                async: Bool = true) {

        super.init(initialItems: initialItems,
                   sectionFunction: { _ in return "_" },
                   sectionType: .prefilled(sections: ["_"]),
                   sortType: sortType,
                   filterType: filterType,
                   searchType: searchType,
                   async: async)
    }

    func flatUpdates(updates: DataSourceUpdates) -> DataSourceUpdates {
        switch updates {
        case .initialSections(let changes):
            if let updates = changes.itemsDiffSteps.first {
                return .initial(changes: updates)
            } else {
                return .initial(changes: ArrayDiff(updates: []))
            }
        case .updateSections(let changes):
            if let updates = changes.itemsDiffSteps.first {
                return .update(changes: updates)
            } else {
                return .update(changes: ArrayDiff(updates: []))
            }
        default:
            return .reload
        }
    }

    override func invokeDelegateUpdate(updates: DataSourceUpdates, operationIndex: Int) {
        super.invokeDelegateUpdate(updates: flatUpdates(updates: updates), operationIndex: operationIndex)
    }

    public func items() -> [Model] {

        guard self.numberOfSections() > 0 else {
            return [Model]()
        }

        return super.itemsInSection(0)
    }
}