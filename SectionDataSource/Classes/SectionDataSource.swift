//
// Created by Mikhail Mulyar on 06/09/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import Foundation
import Dispatch
import PaulHeckelDifference
import SortedArray


public enum SortType<Model:Diffable> {
    ///Sort function
    case unsorted
    case function (function: (Model, Model) -> Bool)

    var function: (Model, Model) -> Bool {
        switch self {
            case .function(let function):
                return function
            case .unsorted:
                return { (_, _) in false }
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

    var prefilled: [String]? {
        if case .prefilled(let sections) = self {
            return sections
        }
        return nil
    }

    var sortingFunction: ((String, String) -> Bool)? {
        if case .sorting(let function) = self {
            return function
        }
        return nil
    }
}


public class SectionDataSource<Model:Searchable>: NSObject, SectionDataSourceProtocol {

    typealias UpdateState = (diff: NestedDiff,
                             identifiers: [String],
                             models: [Model],
                             sectionedItems: [String: SortedArray<Model>],
                             filteredItems: [String: SortedArray<Model>],
                             searchableItems: [String: SortedArray<Model>],
                             filteredPaths: [Int: IndexPath],
                             searchablePaths: [Int: IndexPath])

    public var searchString: String? {
        didSet {
            self.lazySearch()
        }
    }

    public var filterType: FilterType<Model>? {
        didSet {
            self.lazyUpdate()
        }
    }

    public private(set) var isSearching: Bool = false {
        didSet {
            self.delegate?.didUpdateSearchState(isSearching: self.isSearching)
        }
    }

    public var delegate: SectionDataSourceDelegate? = nil

    public var searchLimit: Int? = 50

    public var limitStep = 100

    public var searchInterval: TimeInterval = 0.4 {
        didSet {
            self.lazySearch = {
                return self.debounce(delayBy: .milliseconds(Int(self.searchInterval * 1000))) {
                    [weak self] in
                    self?.recalculateSearch(string: self?.searchString)
                }
            }()
        }
    }

    public var limit: Int? = nil {
        didSet {
            recalculate()
        }
    }

    public var hasMoreData: Bool {
        let count = self.identifiers.map { self.sectionedItems[$0]!.count }.reduce(0, +)
        let currentCount = self.identifiers.map { self.filteredSectionedItems[$0]!.count }.reduce(0, +)
        let limit = self.limit ?? Int.max

        return count > limit && currentCount == limit
    }

    fileprivate lazy var lazyUpdate: () -> Void = {
        return self.debounce(delayBy: .milliseconds(100)) {
            [weak self] in
            self?.recalculate()
        }
    }()

    fileprivate lazy var lazySearch: () -> Void = {
        return self.debounce(delayBy: .milliseconds(Int(self.searchInterval * 1000))) {
            [weak self] in
            self?.recalculateSearch(string: self?.searchString)
        }
    }()

    fileprivate let sectionFunction: (Model) -> (String)
    fileprivate let sortType: SortType<Model>
    fileprivate let searchType: SearchType<Model>
    fileprivate let sectionType: SectionType

    var models: [Model]

    var identifiers = [String]()
    var foundObjects: SortedArray<Model>

    var sectionedItems = [String: SortedArray<Model>]()
    var filteredSectionedItems = [String: SortedArray<Model>]()
    var searchableSectionedItems = [String: SortedArray<Model>]()

    var filteredIndexPaths = [Int: IndexPath]()
    var searchableIndexPaths = [Int: IndexPath]()


    fileprivate(set) var initialized = false

    fileprivate let async: Bool

    fileprivate let workQueue = DispatchQueue(label: "com.dreambits.messenger.dataSourceWorkQueue.\(Int(arc4random_uniform(10)))",
                                              qos: .utility)


    public init(initialItems: [Model] = [Model](),
                sectionFunction: @escaping (Model) -> (String),
                sectionType: SectionType = .sorting(function: <),
                sortType: SortType<Model>,
                filterType: FilterType<Model>? = nil,
                searchType: SearchType<Model> = .searchable,
                async: Bool = true) {

        self.async = async

        self.foundObjects = SortedArray(areInIncreasingOrder: sortType.function)

        self.sortType = sortType
        self.models = initialItems
        self.sectionType = sectionType
        self.sectionFunction = sectionFunction
        self.searchType = searchType
        self.filterType = filterType

        super.init()

        self.setupSections()
    }

    func execute<T>(work: @escaping () -> (T), completion: ((T) -> ())? = nil) {
        if async {
            workQueue.async {
                let val: T = work()
                DispatchQueue.main.sync {
                    completion?(val)
                }
            }
        } else {
            let val: T = work()
            completion?(val)
        }
    }

    func debounce(delayBy: DispatchTimeInterval, queue: DispatchQueue = .main, _ function: @escaping (() -> Void)) -> () -> Void {
        var currentWorkItem: DispatchWorkItem?
        return {
            currentWorkItem?.cancel()
            currentWorkItem = DispatchWorkItem { function() }
            queue.asyncAfter(deadline: .now() + delayBy, execute: currentWorkItem!)
        }
    }

    func invokeDelegateUpdate(updates: DataSourceUpdates) {
        self.delegate?.contentDidUpdate(updates: updates)
    }

    func invokeSearchDelegateUpdate(updates: DataSourceUpdates) {
        self.delegate?.searchContentDidUpdate(updates: updates)
    }

    func recalculate() {
        let work = {
            return self.updateLimit()
        }

        let completion = {
            (updateState: UpdateState) in

            self.update(from: updateState)

            self.invokeDelegateUpdate(updates: .updateSections(changes: updateState.diff))

            if self.isSearching {
                self.lazySearch()
            }
        }

        execute(work: work, completion: completion)
    }

    func recalculateSearch(string: String?) {
        guard let query = string else {
            self.foundObjects.removeAll();

            if self.isSearching {
                self.isSearching = false

                self.invokeSearchDelegateUpdate(updates: .reload)
            }
            return
        }

        let alreadySearching = self.isSearching

        self.isSearching = true

        let work = {
            () -> DataSourceUpdates in
            let found = query.isEmpty ? [Model]() : self.searchObjects(query)

            let previouslyFound = self.foundObjects.array
            self.foundObjects = SortedArray(sorted: found, areInIncreasingOrder: self.sortType.function)

            let updates: DataSourceUpdates

            if alreadySearching {
                let steps = found.difference(from: previouslyFound)
                updates = .update(changes: ArrayDiff(diffSteps: steps))
            } else {
                updates = .reload
            }

            return updates
        }
        let completion = {
            (updates: DataSourceUpdates) -> Void in
            self.invokeSearchDelegateUpdate(updates: updates)
        }
        self.execute(work: work, completion: completion)
    }

    func update(from updateState: UpdateState) {
        self.models = updateState.models
        self.identifiers = updateState.identifiers
        self.sectionedItems = updateState.sectionedItems
        self.filteredSectionedItems = updateState.filteredItems
        self.searchableSectionedItems = updateState.searchableItems
        self.filteredIndexPaths = updateState.filteredPaths
        self.searchableIndexPaths = updateState.searchablePaths
    }

    func setupSections() {

        let work = {
            () -> UpdateState in
            let updateState = self.update(for: self.models)

            self.update(from: updateState)

            return updateState
        }

        let completion = {
            (_: UpdateState) in
            self.initialized = true

            let insertions: Array<Int> = self.identifiers.count > 0 ? Array(0..<self.identifiers.count) : [Int]()

            let nestedDiff = NestedDiff(sectionsDiffSteps: ArrayDiff(inserts: insertions), itemsDiffSteps: [])

            self.invokeDelegateUpdate(updates: .initialSections(changes: nestedDiff))
        }

        execute(work: work, completion: completion)
    }


    public func update(items: [Model]) {

        let work: () -> UpdateState = {
            let updateState = self.update(for: items)
            return updateState
        }

        let completion: (UpdateState) -> () = {
            updateState in

            self.update(from: updateState)

            self.invokeDelegateUpdate(updates: .updateSections(changes: updateState.diff))

            if self.isSearching {
                self.lazySearch()
            }
        }

        self.execute(work: work, completion: completion)
    }

    public func update(with diff: [DiffStep<Model>]) {

        let work: () -> UpdateState? = {
            guard let newModels = try? self.models.apply(steps: diff) else {
                return nil
            }

            let updateState = self.update(for: newModels)
            return updateState
        }

        let completion: (UpdateState?) -> () = {
            updateState in
            guard let updateState = updateState else {
                return
            }

            self.update(from: updateState)

            self.invokeDelegateUpdate(updates: .updateSections(changes: updateState.diff))

            if self.isSearching {
                self.lazySearch()
            }
        }

        self.execute(work: work, completion: completion)
    }

    func update(for newModels: [Model]) -> UpdateState {

        var newIdentifiers = self.sectionType.prefilled ?? [String]()
        var unsortedItems = Array(repeating: [Model](), count: newIdentifiers.count)
        var newSectionItems = [String: SortedArray<Model>]()
        var newFilteredItems = [String: SortedArray<Model>]()
        var newSearchableItems = [String: SortedArray<Model>]()
        var newFilteredPaths = [Int: IndexPath]()
        var newSearchablePaths = [Int: IndexPath]()

        for model in newModels {

            let section = self.sectionFunction(model)

            var index = newIdentifiers.index(of: section)

            if self.sectionType.prefilled == nil, index == nil {
                index = unsortedItems.count
                newIdentifiers.append(section)
                unsortedItems.append([Model]())
            }

            if let i = index {
                unsortedItems[i].append(model)
            }
        }

        switch sectionType {
            case .prefilled:
                break
            case .sorting(let function):
                newIdentifiers.sort(by: function)
        }

        for (index, identifier) in newIdentifiers.enumerated() {
            switch self.sortType {
                case .unsorted:
                    newSectionItems[identifier] = SortedArray(sorted: unsortedItems[index], areInIncreasingOrder: self.sortType.function)
                case .function:
                    newSectionItems[identifier] = SortedArray(unsorted: unsortedItems[index], areInIncreasingOrder: self.sortType.function)
            }
        }

        var itemDiffs: [ArrayDiff] = Array(repeating: ArrayDiff(), count: newIdentifiers.count)

        for (index, identifier) in newIdentifiers.enumerated() {

            guard let new = newSectionItems[identifier] else {
                continue
            }

            var count = newIdentifiers.prefix(index).map { newFilteredItems[$0]?.count ?? 0 }.reduce(0, +)
            let limit = self.limit ?? Int.max

            var searchable = [Model]()
            var filtered = [Model]()

            for model in new {
                if self.filterModel(model) {
                    newSearchablePaths[model.diffIdentifier.hashValue] = IndexPath(row: searchable.count, section: index)
                    searchable.append(model)
                    if count < limit {
                        newFilteredPaths[model.diffIdentifier.hashValue] = IndexPath(row: filtered.count, section: index)
                        filtered.append(model)
                        count += 1
                    }
                }
            }

            if let old = self.filteredSectionedItems[identifier] {
                let steps = filtered.difference(from: old.array)
                itemDiffs[index] = ArrayDiff(diffSteps: steps)
            }

            newFilteredItems[identifier] = SortedArray(sorted: filtered, areInIncreasingOrder: self.sortType.function)
            newSearchableItems[identifier] = SortedArray(sorted: searchable, areInIncreasingOrder: self.sortType.function)
        }

        let sectionDiff: ArrayDiff

        switch sectionType {
            case .prefilled:
                sectionDiff = ArrayDiff()
            case .sorting:
                newIdentifiers = newIdentifiers.filter { (newFilteredItems[$0]?.count ?? 0) > 0 }
                let steps = newIdentifiers.difference(from: self.identifiers)
                sectionDiff = ArrayDiff(diffSteps: steps)
        }

        let nestedDiff = NestedDiff(sectionsDiffSteps: sectionDiff, itemsDiffSteps: itemDiffs)

        return (nestedDiff, newIdentifiers, newModels, newSectionItems, newFilteredItems, newSearchableItems, newFilteredPaths, newSearchablePaths)
    }

    public func loadMoreData() {
        self.limit = (self.limit ?? 0) + self.limitStep
    }

    func updateLimit() -> UpdateState {

        let sectionDiff = ArrayDiff()

        var itemDiffs: [ArrayDiff] = Array(repeating: ArrayDiff(), count: self.sectionedItems.count)

        var count = 0
        let limit = self.limit ?? Int.max

        var newFilteredItems = [String: SortedArray<Model>]()
        var newSearchableItems = [String: SortedArray<Model>]()
        var newFilteredPaths = [Int: IndexPath]()
        var newSearchablePaths = [Int: IndexPath]()

        for (index, identifier) in self.identifiers.enumerated() {
            guard let items = self.sectionedItems[identifier],
                  let oldModels = self.filteredSectionedItems[identifier] else {
                continue
            }

            var filtered = [Model]()
            var searchable = [Model]()

            items.forEach({
                model in
                if self.filterModel(model) {
                    newSearchablePaths[model.diffIdentifier.hashValue] = IndexPath(row: searchable.count, section: index)
                    searchable.append(model)

                    if count < limit {
                        newFilteredPaths[model.diffIdentifier.hashValue] = IndexPath(row: filtered.count, section: index)
                        filtered.append(model)
                        count += 1
                    }
                }
            })

            let steps = filtered.difference(from: oldModels.array)

            newFilteredItems[identifier] = SortedArray(sorted: filtered, areInIncreasingOrder: self.sortType.function)
            newSearchableItems[identifier] = SortedArray(sorted: searchable, areInIncreasingOrder: self.sortType.function)

            itemDiffs[self.identifiers.index(of: identifier)!] = ArrayDiff(diffSteps: steps)
        }

        let nestedDiff = NestedDiff(sectionsDiffSteps: sectionDiff, itemsDiffSteps: itemDiffs)

        return (nestedDiff,
                self.identifiers,
                self.models,
                self.sectionedItems,
                newFilteredItems,
                newSearchableItems,
                newFilteredPaths,
                newSearchablePaths)
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

    func itemsInSection(_ section: Int) -> [Model] {
        let identifier = identifiers[section]
        let items = filteredSectionedItems[identifier]!

        return items.array
    }

    func itemAtIndexPath(_ path: IndexPath) -> Model {

        let identifier = identifiers[path.section]
        let items = filteredSectionedItems[identifier]!

        return items[path.row]
    }

    func indexPath(for item: Model) -> IndexPath? {
        guard self.initialized else {
            return nil
        }
        return self.filteredIndexPaths[item.diffIdentifier.hashValue]
    }

    func numberOfItemsInSection(_ section: Int) -> Int {

        guard self.initialized else {
            return 0
        }

        let identifier = identifiers[section]
        let items = filteredSectionedItems[identifier]

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

    func searchedItemsInSection(_ section: Int) -> [Model] {
        return self.foundObjects.array
    }

    func searchedItemAtIndexPath(_ path: IndexPath) -> Model {
        return self.foundObjects[path.row]
    }

    func searchedIndexPath(for item: Model) -> IndexPath? {
        return self.searchableIndexPaths[item.diffIdentifier.hashValue]
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
            case .unsorted:
                return unsorted
            case .function(let function):
                return unsorted.sorted(by: function)
        }
    }

    func filterModel(_ unfiltered: Model) -> Bool {
        guard let filter = self.filterType else {
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
