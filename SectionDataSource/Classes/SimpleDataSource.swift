//
// Created by Mikhail Mulyar on 24/09/2017.
//

// Flat data source with only 1 section
public class SimpleDataSource<Model: Diffable>: SectionDataSource<Model> {

    public init(initialItems: [Model] = [Model](),
                sortType: SortType<Model>,
                filterType: FilterType<Model>? = nil,
                searchType: SearchType<Model> = .searchable,
                async: Bool = true) {

        super.init(initialItems: initialItems,
                   sectionFunction: { _ in ["_"] },
                   sectionType: .prefilled(sections: ["_"]),
                   sortType: sortType,
                   filterType: filterType,
                   searchType: searchType,
                   async: async)
    }

    public func items() -> [Model] {

        guard self.numberOfSections() > 0 else {
            return [Model]()
        }

        return super.itemsInSection(0)
    }
}
