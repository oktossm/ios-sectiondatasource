//
// Created by Mikhail Mulyar on 24/09/2017.
//

import ReactiveSwift
import enum Result.NoError


public class SimpleDataSource<Model:Searchable>: SectionDataSource<Model> {

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

    public override var contentChangesSignal: Signal<DataSourceUpdates, NoError> {
        return super.contentChangesSignal.map {
            updates in

            switch updates {
                case .updateSections(let changes):
                    if let updates = changes.itemsDiffSteps.first {
                        return DataSourceUpdates.update(changes: updates)
                    } else {
                        fallthrough
                    }
                default:
                    return updates
            }
        }
    }
    public override var searchContentChangesSignal: Signal<DataSourceUpdates, NoError> {
        return super.searchContentChangesSignal.map {
            updates in

            switch updates {
                case .updateSections(let changes):
                    if let updates = changes.itemsDiffSteps.first {
                        return DataSourceUpdates.update(changes: updates)
                    } else {
                        fallthrough
                    }
                default:
                    return updates
            }
        }
    }

    public func items() -> [Model] {

        guard self.numberOfSections() > 0 else {
            return [Model]()
        }

        return super.itemsInSection(0)
    }
}