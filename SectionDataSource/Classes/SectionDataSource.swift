//
// Created by Mikhail Mulyar on 06/09/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import ReactiveSwift
import PaulHeckelDifference
import SortedArray
import enum Result.NoError

public enum SortType<Model:Diffable> {
    ///Sort function
    case function (function: (Model, Model) -> Bool)


    var function: (Model, Model) -> Bool {
        switch self {
            case .function(let function):
                return function
        }
    }
}


public enum SearchType<Model:Searchable> {
    ///Search using default method of protocol Searchable
    case searchable
    ///Search in memory using custom function
    case function (function: (Model, String) -> Bool)
    ///Search using predicate for property
//    case objectProperty (property: String)
}


public enum FilterType<Model:Diffable> {
    ///Filter in memory using models
    case function (function: (Model) -> Bool)
}


public enum SectionType {
    ///Prefilled list of sections. Static sections list, will not change.
    case prefilled(sections: [String])
    ///Sorting algorithm for sections. Sections will be generated dynamically for items.
    case sorting (function: (String, String) -> Bool)

    var prefilled: Bool {
        if case .prefilled = self {
            return true
        }
        return false
    }

    var sortingFunction: ((String, String) -> Bool)? {
        if case .sorting(let function) = self {
            return function
        }
        return nil
    }
}


public class SectionDataSource<Model:Searchable>: SectionDataSourceProtocol {

    typealias UpdateState = (diff: NestedDiff,
                             identifiers: [String],
                             models: [Model],
                             sectionedItems: [String: SortedArray<Model>],
                             filteredItems: [String: SortedArray<Model>],
                             searchableItems: [String: SortedArray<Model>])

    public let contentChangesSignal: Signal<DataSourceUpdates, NoError>

    public let searchContentChangesSignal: Signal<DataSourceUpdates, NoError>

    public let searchString: MutableProperty<String?> = MutableProperty(nil)

    public let isSearching: ReactiveSwift.Property<Bool>

    let filter: MutableProperty<FilterType<Model>?> = MutableProperty(nil)

    var searchLimit: Int? = 50

    var limitStep = 100

    var limit: Int? = 100 {
        didSet {
            workQueue.async {
                let nestedDiff: NestedDiff = self.filterOperation()

                DispatchQueue.main.async {
                    self.contentChangesObserver.send(value: .updateSections(changes: nestedDiff))

                    if self.isSearching.value {
                        self.searchString.value = self.searchString.value
                    }
                }
            }
        }
    }

    var hasMoreData: Bool {
        let count = self.identifiers.map { self.sectionedItems[$0]!.count }.reduce(0, +)
        let currentCount = self.identifiers.map { self.filteredSectionedItems[$0]!.count }.reduce(0, +)
        let limit = self.limit ?? Int.max

        return count > limit && currentCount == limit
    }


    fileprivate let contentChangesObserver:       Observer<DataSourceUpdates, NoError>
    fileprivate let searchContentChangesObserver: Observer<DataSourceUpdates, NoError>


    fileprivate let sectionFunction: (Model) -> (String)
    fileprivate let sortType:        SortType<Model>
    fileprivate let searchType:      SearchType<Model>
    fileprivate let sectionType:     SectionType

    fileprivate var models: [Model]

    fileprivate var identifiers = [String]()
    fileprivate var foundObjects: SortedArray<Model>

    fileprivate var sectionedItems           = [String: SortedArray<Model>]()
    fileprivate var filteredSectionedItems   = [String: SortedArray<Model>]()
    fileprivate var searchableSectionedItems = [String: SortedArray<Model>]()


    fileprivate var initialized = false

    fileprivate let workQueue = DispatchQueue(label: "com.dreambits.messenger.dataSourceWorkQueue", qos: .userInitiated)


    init(initialItems: [Model]? = nil,
         sectionFunction: @escaping (Model) -> (String),
         sortType: SortType<Model>,
         sectionType: SectionType = .sorting(function: <),
         filterType: FilterType<Model>? = nil,
         searchType: SearchType<Model> = .searchable) {

        self.foundObjects = SortedArray(areInIncreasingOrder: sortType.function)

        self.sortType = sortType
        self.models = initialItems ?? [Model]()
        self.sectionType = sectionType
        self.sectionFunction = sectionFunction
        self.searchType = searchType

        let (signal, observer) = Signal<DataSourceUpdates, NoError>.pipe()

        contentChangesSignal = signal
        contentChangesObserver = observer

        let (sSignal, sObserver) = Signal<DataSourceUpdates, NoError>.pipe()

        searchContentChangesSignal = sSignal
        searchContentChangesObserver = sObserver

        let (isSearchingSignal, isSearchingObserver) = Signal<Bool, NoError>.pipe()

        isSearching = ReactiveSwift.Property(initial: false, then: isSearchingSignal)


        self.filter.value = filterType

        self.filter.signal.throttle(0.1, on: QueueScheduler.main).observeValues {
            [unowned self] filter in

            self.limit = self.limitStep
        }

        self.searchString.signal.throttle(0.5, on: QueueScheduler.main).combinePrevious(self.searchString.value).observeValues {
            [unowned self] (oldString, string) in

            guard let query = string else {
                self.foundObjects.removeAll();

                if self.isSearching.value {
                    isSearchingObserver.send(value: false)

                    let diff = NestedDiff(sectionsDiffSteps: ArrayDiff(updates: [(0, 0)]), itemsDiffSteps: [])

                    self.searchContentChangesObserver.send(value: .updateSections(changes: diff))
                }
                return
            }

            let alreadySearching = self.isSearching.value

            isSearchingObserver.send(value: true)

            self.workQueue.async {
                let found = query.isEmpty ? [Model]() : self.searchObjects(query)

                let previouslyFound = self.foundObjects.array
                self.foundObjects = SortedArray(sorted: found, areInIncreasingOrder: self.sortType.function)

                let diff: NestedDiff

                if alreadySearching {
                    let steps = found.difference(from: previouslyFound)
                    diff = NestedDiff(sectionsDiffSteps: ArrayDiff(), itemsDiffSteps: [ArrayDiff(diffSteps: steps)])
                }
                else {
                    diff = NestedDiff(sectionsDiffSteps: ArrayDiff(updates: [(0, 0)]), itemsDiffSteps: [])
                }

                DispatchQueue.main.async {
                    self.searchContentChangesObserver.send(value: .updateSections(changes: diff))

                }
            }
        }

        self.setupSections()
    }

    func setupSections() {

        workQueue.async {
            switch self.sectionType {
                case .prefilled(let identifiers):
                    self.identifiers = identifiers
                    identifiers.forEach { self.sectionedItems[$0] = SortedArray(areInIncreasingOrder: self.sortType.function) }
                case .sorting:
                    break
            }

            for model in self.models {
                let section = self.sectionFunction(model)

                if self.sectionType.prefilled == false, self.identifiers.contains(section) == false {
                    self.identifiers.append(section)
                    self.sectionedItems[section] = SortedArray(areInIncreasingOrder: self.sortType.function)
                }
                else {
                    self.sectionedItems[section]?.insert(model)
                }
            }

            if let function = self.sectionType.sortingFunction {
                self.identifiers.sort(by: function)
            }

            var count = 0
            let limit = self.limit ?? Int.max

            for identifier in self.identifiers {

                var sorted = [Model]()

                var searchable = [Model]()
                var filtered   = [Model]()

                self.sectionedItems[identifier]?.forEach({
                    model in

                    sorted.append(model)

                    if self.filterModel(model) {

                        searchable.append(model)

                        if count < limit {
                            filtered.append(model)
                            count += 1
                        }
                    }
                })

                self.filteredSectionedItems[identifier] = SortedArray(sorted: filtered, areInIncreasingOrder: self.sortType.function)
                self.searchableSectionedItems[identifier] = SortedArray(sorted: searchable, areInIncreasingOrder: self.sortType.function)
            }

            DispatchQueue.main.async {

                self.initialized = true

                let insertions: Array<Int> = self.identifiers.count > 0 ? Array(0..<self.identifiers.count) : [Int]()

                let nestedDiff = NestedDiff(sectionsDiffSteps: ArrayDiff(inserts: insertions), itemsDiffSteps: [])

                self.contentChangesObserver.send(value: .updateSections(changes: nestedDiff))
            }
        }
    }


    func update(items: [Model]) {

        if self.isSearching.value {
            self.searchString.value = self.searchString.value
        }

        workQueue.async {
            let diff        = items.difference(from: self.models)
            let updateState = self.update(for: items, diff: diff)

            DispatchQueue.main.async {
                self.identifiers = updateState.identifiers
                self.models = updateState.models
                self.sectionedItems = updateState.sectionedItems
                self.filteredSectionedItems = updateState.filteredItems
                self.searchableSectionedItems = updateState.searchableItems

                self.contentChangesObserver.send(value: .updateSections(changes: updateState.diff))

                if self.isSearching.value {
                    self.searchString.value = self.searchString.value
                }
            }
        }
    }

    func updateItems(with diff: [DiffStep<Model>]) {

        workQueue.async {
            guard let newModels = try? self.models.apply(steps: diff) else {
                return
            }

            let updateState = self.update(for: newModels, diff: diff)

            DispatchQueue.main.async {
                self.identifiers = updateState.identifiers
                self.models = updateState.models
                self.sectionedItems = updateState.sectionedItems
                self.filteredSectionedItems = updateState.filteredItems
                self.searchableSectionedItems = updateState.searchableItems

                self.contentChangesObserver.send(value: .updateSections(changes: updateState.diff))

                if self.isSearching.value {
                    self.searchString.value = self.searchString.value
                }
            }
        }
    }

    private func update(for newModels: [Model], diff: [DiffStep<Model>]) -> UpdateState {

        //Update delete steps with local values for consistency
        let diff = diff.map {
            (step: DiffStep<Model>) -> DiffStep<Model> in

            switch step {
                case .delete(_, let index):
                    return .delete(value: self.models[index], index: index)
                default:
                    return step
            }
        }

        var updatedSections = [String: [Model]]()

        for step in diff {
            switch step {
                case let .insert(value, _):
                    let identifier = self.sectionFunction(value)
                    var items      = updatedSections[identifier] ?? self.sectionedItems[identifier]?.array ?? [Model]()
                    items.append(value)
                    updatedSections[identifier] = items
                case let .delete(value, _):
                    let identifier = self.sectionFunction(value)
                    var items      = updatedSections[identifier] ?? self.sectionedItems[identifier]?.array ?? [Model]()

                    for (index, model) in items.enumerated() {
                        if model.diffIdentifier == value.diffIdentifier {
                            items.remove(at: index)
                            break
                        }
                    }

                    updatedSections[identifier] = items
                case let .move(value, _, _):
                    let identifier = self.sectionFunction(value)
                    var items      = updatedSections[identifier] ?? self.sectionedItems[identifier]?.array ?? [Model]()

                    for (index, model) in items.enumerated() {
                        if model.diffIdentifier == value.diffIdentifier {
                            items.remove(at: index)
                            break
                        }
                    }
                    items.append(value)
                    updatedSections[identifier] = items
                    break
                case let .update(value, _, _):
                    let identifier = self.sectionFunction(value)
                    var items      = updatedSections[identifier] ?? self.sectionedItems[identifier]?.array ?? [Model]()

                    for (index, model) in items.enumerated() {
                        if model.diffIdentifier == value.diffIdentifier {
                            items.remove(at: index)
                            break
                        }
                    }
                    items.append(value)
                    updatedSections[identifier] = items
            }
        }


        var newIdentifiers     = self.identifiers
        var newSectionItems    = self.sectionedItems
        var newFilteredItems   = self.filteredSectionedItems
        var newSearchableItems = self.searchableSectionedItems

        let sectionDiff: ArrayDiff

        switch sectionType {
            case .prefilled:
                sectionDiff = ArrayDiff()
            case .sorting(let function):
                for (identifier, updated) in updatedSections {
                    if updated.count == 0 {
                        newIdentifiers.removeObject(identifier)
                        updatedSections[identifier] = nil
                        newSectionItems[identifier] = nil
                    }
                    else if !newIdentifiers.contains(identifier) {
                        newIdentifiers.append(identifier)
                    }
                }

                newIdentifiers.sort(by: function)

                let steps = newIdentifiers.difference(from: self.identifiers)

                sectionDiff = ArrayDiff(diffSteps: steps)
        }

        var itemDiffs: [ArrayDiff] = Array(repeating: ArrayDiff(), count: self.identifiers.count)

        for (identifier, updated) in updatedSections {

            guard let index = newIdentifiers.index(of: identifier) else {
                continue
            }

            var count = newIdentifiers.prefix(index).map { newFilteredItems[$0]?.count ?? 0 }.reduce(0, +)
            let limit = self.limit ?? Int.max

            let new = SortedArray(unsorted: updated, areInIncreasingOrder: self.sortType.function)

            var searchable = [Model]()
            var filtered   = [Model]()

            new.forEach({
                model in

                if self.filterModel(model) {
                    searchable.append(model)

                    if count < limit {
                        filtered.append(model)
                        count += 1
                    }
                }
            })

            if let old = self.filteredSectionedItems[identifier] {
                let steps = filtered.difference(from: old.array)
                itemDiffs[index] = ArrayDiff(diffSteps: steps)
            }

            newSectionItems[identifier] = new
            newFilteredItems[identifier] = SortedArray(sorted: filtered, areInIncreasingOrder: self.sortType.function)
            newSearchableItems[identifier] = SortedArray(sorted: searchable, areInIncreasingOrder: self.sortType.function)
        }

        let nestedDiff = NestedDiff(sectionsDiffSteps: sectionDiff, itemsDiffSteps: itemDiffs)

        return (nestedDiff, newIdentifiers, newModels, newSectionItems, newFilteredItems, newSearchableItems)
    }

    func loadMoreData() {
        self.limit = (self.limit ?? 0) + self.limitStep
    }

    func filterOperation() -> NestedDiff {

        let sectionDiff = ArrayDiff()

        var itemDiffs: [ArrayDiff] = Array(repeating: ArrayDiff(), count: self.sectionedItems.count)

        var count = 0
        let limit = self.limit ?? Int.max

        for identifier in self.identifiers {
            guard let items = self.sectionedItems[identifier],
                  let oldModels = self.filteredSectionedItems[identifier] else {
                continue
            }

            var filtered   = [Model]()
            var searchable = [Model]()

            items.forEach({
                model in
                if self.filterModel(model) {
                    searchable.append(model)

                    if count < limit {
                        filtered.append(model)
                        count += 1
                    }
                }
            })

            let steps = filtered.difference(from: oldModels.array)

            self.filteredSectionedItems[identifier] = SortedArray(sorted: filtered, areInIncreasingOrder: self.sortType.function)
            self.searchableSectionedItems[identifier] = SortedArray(sorted: searchable, areInIncreasingOrder: self.sortType.function)

            itemDiffs[self.identifiers.index(of: identifier)!] = ArrayDiff(diffSteps: steps)
        }

        return NestedDiff(sectionsDiffSteps: sectionDiff, itemsDiffSteps: itemDiffs)
    }

    func searchObjects(_ query: String) -> [Model] {

        var found = [Model]()

        for identifier in identifiers {
            let models = self.searchableSectionedItems[identifier]
            if let m = models {
                let a = self.searchModels(m.array, query: query)
                found += a
            }
        }

        guard let limit = self.searchLimit else {
            return found
        }

        return Array(found.prefix(limit))
    }
}


//MARK: - Data source


public extension SectionDataSource {

    func itemAtIndexPath(_ path: IndexPath) -> Model {

        let identifier = identifiers[path.section]
        let items      = filteredSectionedItems[identifier]!

        return items[path.row]
    }

    func numberOfItemsInSection(_ section: Int) -> Int {

        let identifier = identifiers[section]
        let items      = filteredSectionedItems[identifier]

        return items?.count ?? 0
    }

    func numberOfSections() -> Int {

        guard self.initialized else {
            return 0
        }

        return identifiers.count
    }

    func sectionIdForSection(_ section: Int) -> String {
        let identifier = identifiers[section]
        return identifier
    }
}


//MARK: - Search Data source


public extension SectionDataSource {

    func searchedItemAtIndexPath(_ path: IndexPath) -> Model {
        return self.foundObjects[path.row]
    }

    func searchedNumberOfItemsInSection(_ section: Int) -> Int {
        return self.foundObjects.count
    }

    func searchedNumberOfSections() -> Int {
        guard self.initialized else {
            return 0
        }
        return 1
    }

    func searchedSectionIdForSection(_ section: Int) -> String {
        return SearchSection
    }
}


//MARK: - Search and sort


extension SectionDataSource {

    func sorted(_ unsorted: [Model]) -> [Model] {

        switch self.sortType {
            case .function(let function):
                return unsorted.sorted(by: function)
        }
    }

    func filterModel(_ unfiltered: Model) -> Bool {
        guard let filter = self.filter.value else {
            return true
        }

        switch filter {
            case let .function(function):
                return function(unfiltered)
        }
    }

    func searchModels(_ list: [Model], query: String) -> [Model] {

        let searchType: SearchType<Model> = self.searchType

        switch searchType {
            case .searchable:
                return list.filter { $0.pass(query) }
            case .function(let function):
                return list.filter { function($0, query) }
        }
    }
}


//MARK: - Remove object


extension RangeReplaceableCollection where Iterator.Element: Equatable {
    
    // Remove first collection element that is equal to the given `object`:
    mutating func removeObject(_ object: Iterator.Element) {
        if let index = self.index(of: object) {
            self.remove(at: index)
        }
    }
}
