//
// Created by Mikhail Mulyar on 06/09/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import Foundation
import Dispatch
import DifferenceKit


public enum SortType<Model: Diffable> {
    ///Sort function
    case unsorted
    case comparable(ascending: Bool)
    case function (function: (Model, Model) -> Bool)
}


extension SortType {
    var function: (Model, Model) -> Bool {
        switch self {
        case .function(let function):
            return function
        case .comparable:
            return { (_, _) in false }
        case .unsorted:
            return { (_, _) in false }
        }
    }
}


extension SortType where Model: Comparable {
    var function: (Model, Model) -> Bool {
        switch self {
        case .function(let function):
            return function
        case .comparable(let ascending):
            return { ascending ? $0 < $1 : $0 > $1 }
        case .unsorted:
            return { (_, _) in false }
        }
    }
}


public enum SearchType<Model: Searchable> {
    ///Search using default method of protocol Searchable
    case searchable
    ///Search in memory using custom function
    case function (function: (Model, String) -> Bool)
}


public enum FilterType<Model: Diffable> {
    ///Filter using default method of protocol Filterable
    case filterable
    ///Filter in memory using models
    case function (function: (Model) -> Bool)

    var function: (Model) -> Bool {
        switch self {
        case .filterable:
            return { $0.isIncluded() }
        case .function(let function):
            return function
        }
    }
}


public enum SectionType {
    ///Prefilled list of sections. Static sections list, will not change.
    case prefilled(sections: [String])
    ///Sorting algorithm for sections. Sections will be generated dynamically for items.
    ///Sections which have 0 items will not be displayed in list.
    case sorting (function: (String, String) -> Bool)
    ///Same as `sorting`. But it keeps sections with 0 items in list after filtering applied.
    ///It is useful in case of implementing collapsable sections using internal filter.
    case collapsableSorting (function: (String, String) -> Bool)

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
        if case .collapsableSorting(let function) = self {
            return function
        }
        return nil
    }
}


extension String: Diffable {}


public class SectionDataSource<Model: Diffable>: NSObject, SectionDataSourceProtocol {

    typealias UpdateState = (changeSet: StagedChangeset<[ArraySection<String, Model>]>,
                             identifiers: [String],
                             unfilteredIdentifiers: [String],
                             models: [Model],
                             sectionedItems: [String: SortedArray<Model>],
                             filteredItems: [String: SortedArray<Model>],
                             searchableItems: [String: SortedArray<Model>],
                             filteredPaths: [Int: IndexPath])

    typealias SearchUpdateState = (changeSet: StagedChangeset<[Model]>?, foundObjects: SortedArray<Model>)

    public var searchString: String? {
        didSet {
            self.lazySearch()
        }
    }

    public var searchType: SearchType<Model> {
        didSet {
            self.lazySearch()
        }
    }


    public var filterType: FilterType<Model>? {
        didSet {
            self.lazyUpdate()
        }
    }

    public var sortType: SortType<Model> {
        didSet {
            self.lazySortUpdate()
        }
    }

    public var sectionFunction: (Model) -> [String] {
        didSet {
            self.lazyForceUpdate()
        }
    }
    public var sectionType: SectionType {
        didSet {
            self.lazyForceUpdate()
        }
    }

    public var allItems: [Model] {
        self.models
    }

    public private(set) var isSearching: Bool = false {
        didSet {
            self.delegate?.dataSource(self, didUpdateSearchState: isSearching)
        }
    }

    public weak var delegate: SectionDataSourceDelegate?

    public var searchLimit: Int? = 50

    public var limitStep = 100

    public var searchInterval: TimeInterval = 0.4 {
        didSet {
            self.lazySearch = {
                SectionDataSource.debounce(delayBy: .milliseconds(Int(self.searchInterval * 1000))) {
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

    public internal (set) var operationIndex: OperationIndex = 0

    fileprivate lazy var lazyUpdate: () -> Void = {
        SectionDataSource.debounce(delayBy: .milliseconds(100)) {
            [weak self] in
            self?.recalculate()
        }
    }()

    fileprivate lazy var lazyForceUpdate: () -> Void = {
        SectionDataSource.debounce(delayBy: .milliseconds(100)) {
            [weak self] in
            self?.recalculate(force: true)
        }
    }()

    fileprivate lazy var lazySortUpdate: () -> Void = {
        SectionDataSource.debounce(delayBy: .milliseconds(100)) {
            [weak self] in
            self?.recalculate(updateSorting: true)
        }
    }()

    fileprivate lazy var lazySearch: () -> Void = {
        SectionDataSource.debounce(delayBy: .milliseconds(Int(self.searchInterval * 1000))) {
            [weak self] in
            self?.recalculateSearch(string: self?.searchString)
        }
    }()

    var models: [Model]

    var identifiers = [String]()
    var unfilteredIdentifiers = [String]()
    var foundObjects: SortedArray<Model>

    var sectionedItems = [String: SortedArray<Model>]()
    var filteredSectionedItems = [String: SortedArray<Model>]()
    var searchableSectionedItems = [String: SortedArray<Model>]()

    var filteredIndexPaths = [Int: IndexPath]()

    fileprivate(set) var initialized = false

    fileprivate let async: Bool

    fileprivate let workQueue = DispatchQueue(label: "mm.sectionDataSource.dataSourceWorkQueue", qos: .utility)

    public init(initialItems: [Model] = [Model](),
                sectionFunction: @escaping (Model) -> [String],
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

    func execute<T>(work: @escaping () -> T, completion: ((T) -> ())? = nil) {
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

    class func debounce(delayBy: DispatchTimeInterval, queue: DispatchQueue = .main, _ function: @escaping () -> Void) -> () -> Void {
        var currentWorkItem: DispatchWorkItem?
        return {
            currentWorkItem?.cancel()
            currentWorkItem = DispatchWorkItem { function() }
            queue.asyncAfter(deadline: .now() + delayBy, execute: currentWorkItem!)
        }
    }

    func invokeDelegateUpdate(updates: DataSourceUpdates, operationIndex: OperationIndex) {
        self.delegate?.dataSource(self, didUpdateContent: updates, operationIndex: operationIndex)
    }

    func invokeSearchDelegateUpdate(updates: DataSourceUpdates) {
        self.delegate?.dataSource(self, didUpdateSearchContent: updates)
    }

    func recalculate(updateSorting: Bool = false, force: Bool = false) {
        operationIndex += 1
        let currentOperationIndex = operationIndex

        let work = {
            () -> UpdateState in
            if (updateSorting && self.limit != nil) || force {
                return self.update(for: self.models)
            } else {
                return self.updateLimit(updateSorting: updateSorting)
            }
        }

        let completion = {
            (updateState: UpdateState) in

            let steps: OrderedChangeSteps = self.prepareChangeSteps(for: updateState)
            self.invokeDelegateUpdate(updates: .update(changes: steps), operationIndex: currentOperationIndex)

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
            () -> SearchUpdateState in
            let found = query.isEmpty ? [Model]() : self.searchObjects(query)

            let foundObjects = SortedArray(sorted: found, areInIncreasingOrder: self.sortType.function)

            let changeSet: StagedChangeset<[Model]>?
            if alreadySearching {
                changeSet = StagedChangeset(source: self.foundObjects.sortedElements, target: foundObjects.sortedElements)
            } else {
                changeSet = nil
            }

            return (changeSet, foundObjects)
        }
        let completion = {
            (updateState: SearchUpdateState) -> Void in

            let updates: DataSourceUpdates
            let steps = self.prepareSearchChangeSteps(for: updateState)
            if alreadySearching, let steps = steps {
                updates = .update(changes: steps)
            } else {
                updates = .reload
            }

            self.invokeSearchDelegateUpdate(updates: updates)
        }
        self.execute(work: work, completion: completion)
    }

    func updateInitial(from updateState: UpdateState) {
        self.models = updateState.models
        self.unfilteredIdentifiers = updateState.unfilteredIdentifiers
        self.sectionedItems = updateState.sectionedItems
        self.searchableSectionedItems = updateState.searchableItems
        self.filteredIndexPaths = updateState.filteredPaths
    }

    func updateFinal(from updateState: UpdateState) {
        self.models = updateState.models
        self.identifiers = updateState.identifiers
        self.unfilteredIdentifiers = updateState.unfilteredIdentifiers
        self.sectionedItems = updateState.sectionedItems
        self.filteredSectionedItems = updateState.filteredItems
        self.searchableSectionedItems = updateState.searchableItems
        self.filteredIndexPaths = updateState.filteredPaths
    }

    func setupSections() {
        let currentOperationIndex = operationIndex

        let work = {
            () -> UpdateState in
            let updateState = self.update(for: self.models)

            return updateState
        }

        let completion = {
            (updateState: UpdateState) in

            self.initialized = true

            let steps: OrderedChangeSteps = self.prepareChangeSteps(for: updateState)
            self.invokeDelegateUpdate(updates: .initial(changes: steps), operationIndex: currentOperationIndex)
        }

        execute(work: work, completion: completion)
    }

    @discardableResult
    public func update(items: [Model]) -> OperationIndex {

        operationIndex += 1
        let currentOperationIndex = operationIndex

        let work: () -> UpdateState = {
            let updateState = self.update(for: items)
            return updateState
        }

        let completion: (UpdateState) -> () = {
            updateState in

            let steps: OrderedChangeSteps = self.prepareChangeSteps(for: updateState)
            self.invokeDelegateUpdate(updates: .update(changes: steps), operationIndex: currentOperationIndex)

            if self.isSearching {
                self.lazySearch()
            }
        }

        self.execute(work: work, completion: completion)

        return currentOperationIndex
    }

    @discardableResult
    public func add(item: Model) -> OperationIndex {
        var newModels = self.models
        newModels.append(item)
        return self.update(items: newModels)
    }

    @discardableResult
    public func add(items: [Model]) -> OperationIndex {
        var newModels = self.models
        newModels.append(contentsOf: items)
        return self.update(items: newModels)
    }

    @discardableResult
    public func delete(item: Model) -> OperationIndex {
        var newModels = self.models

        if let index = newModels.firstIndex(where: { $0.differenceIdentifier == item.differenceIdentifier }) {
            newModels.remove(at: index)
        }

        return self.update(items: newModels)
    }

    @discardableResult
    public func delete(items: [Model]) -> OperationIndex {
        var newModels = self.models

        for item in items {
            if let index = newModels.firstIndex(where: { $0.differenceIdentifier == item.differenceIdentifier }) {
                newModels.remove(at: index)
            }
        }

        return self.update(items: newModels)
    }

    @discardableResult
    public func replace(item: Model) -> OperationIndex {
        var newModels = self.models

        if let index = newModels.firstIndex(where: { $0.differenceIdentifier == item.differenceIdentifier }) {
            newModels.replaceSubrange(index..<(index + 1), with: [item])
        }

        return self.update(items: newModels)
    }

    @discardableResult
    public func replace(items: [Model]) -> OperationIndex {
        var newModels = self.models

        for item in items {
            if let index = newModels.firstIndex(where: { $0.differenceIdentifier == item.differenceIdentifier }) {
                newModels.replaceSubrange(index..<(index + 1), with: [item])
            }
        }

        return self.update(items: newModels)
    }

    public func forceUpdate() -> OperationIndex {
        self.recalculate(force: true)

        return operationIndex
    }

    func update(for newModels: [Model]) -> UpdateState {

        var newUnfilteredIdentifiers = self.sectionType.prefilled ?? [String]()
        var newIdentifiers = newUnfilteredIdentifiers
        var unsortedItems = Dictionary(uniqueKeysWithValues: newUnfilteredIdentifiers.map { ($0, [Model]()) })
        var newSectionItems = [String: SortedArray<Model>]()
        var newFilteredItems = [String: SortedArray<Model>]()
        var newSearchableItems = [String: SortedArray<Model>]()
        var newFilteredPaths = [Int: IndexPath]()

        for model in newModels {

            let sections = self.sectionFunction(model)

            for section in sections {
                let sectionItems = unsortedItems[section]

                if self.sectionType.prefilled == nil, sectionItems == nil {
                    newUnfilteredIdentifiers.append(section)
                    unsortedItems[section] = [model]
                } else {
                    unsortedItems[section]?.append(model)
                }
            }
        }

        switch sectionType {
        case .prefilled:
            break
        case .sorting(let function), .collapsableSorting(let function):
            newUnfilteredIdentifiers.sort(by: function)
        }

        for section in newUnfilteredIdentifiers {
            guard let items = unsortedItems[section] else {
                newSectionItems[section] = SortedArray(sorted: [], areInIncreasingOrder: self.sortType.function)
                continue
            }
            switch self.sortType {
            case .unsorted:
                newSectionItems[section] = SortedArray(sorted: items, areInIncreasingOrder: self.sortType.function)
            case .function, .comparable:
                newSectionItems[section] = SortedArray(unsorted: items, areInIncreasingOrder: self.sortType.function)
            }
        }

        for (index, identifier) in newUnfilteredIdentifiers.enumerated() {

            guard let new = newSectionItems[identifier] else {
                continue
            }

            var count = newUnfilteredIdentifiers.prefix(index).map { newFilteredItems[$0]?.count ?? 0 }.reduce(0, +)
            let limit = self.limit ?? Int.max

            var searchable = [Model]()
            var filtered = [Model]()

            for model in new {
                if self.filterModel(model) {
                    searchable.append(model)
                    if count < limit {
                        newFilteredPaths[model.differenceIdentifier.hashValue] = IndexPath(item: filtered.count, section: index)
                        filtered.append(model)
                        count += 1
                    }
                }
            }

            let sorted = SortedArray(sorted: filtered, areInIncreasingOrder: self.sortType.function)
            newFilteredItems[identifier] = sorted
            newSearchableItems[identifier] = SortedArray(sorted: searchable, areInIncreasingOrder: self.sortType.function)
        }

        switch sectionType {
        case .prefilled:
            break
        case .sorting:
            newIdentifiers = newUnfilteredIdentifiers.filter { (newFilteredItems[$0]?.count ?? 0) > 0 }
        case .collapsableSorting:
            break
        }

        let newCollection: [ArraySection<String, Model>] = newIdentifiers.map {
            ArraySection(model: $0, elements: newFilteredItems[$0]?.sortedElements ?? [])
        }

        let oldCollection: [ArraySection<String, Model>] = self.identifiers.map {
            ArraySection(model: $0, elements: self.filteredSectionedItems[$0]?.sortedElements ?? [])
        }

        let changeSet = StagedChangeset(source: oldCollection, target: newCollection)

        return (changeSet,
                newIdentifiers,
                newUnfilteredIdentifiers,
                newModels,
                newSectionItems,
                newFilteredItems,
                newSearchableItems,
                newFilteredPaths)
    }

    public func loadMoreData() -> OperationIndex {
        self.limit = (self.limit ?? 0) + self.limitStep
        return operationIndex
    }

    func updateLimit(updateSorting: Bool = false) -> UpdateState {

        var count = 0
        let limit = self.limit ?? Int.max

        var newFilteredItems = [String: SortedArray<Model>]()
        var newSearchableItems = [String: SortedArray<Model>]()
        var newFilteredPaths = [Int: IndexPath]()

        for (index, identifier) in self.unfilteredIdentifiers.enumerated() {
            guard let items = self.sectionedItems[identifier] else {
                continue
            }

            var filtered = [Model]()
            var searchable = [Model]()

            items.forEach({
                model in
                if self.filterModel(model) {
                    searchable.append(model)

                    if count < limit {
                        newFilteredPaths[model.differenceIdentifier.hashValue] = IndexPath(item: filtered.count, section: index)
                        filtered.append(model)
                        count += 1
                    }
                }
            })

            let sorted: SortedArray<Model>
            let searchableSorted: SortedArray<Model>
            if updateSorting {
                sorted = SortedArray(unsorted: filtered, areInIncreasingOrder: self.sortType.function)
                searchableSorted = SortedArray(unsorted: searchable, areInIncreasingOrder: self.sortType.function)
            } else {
                sorted = SortedArray(sorted: filtered, areInIncreasingOrder: self.sortType.function)
                searchableSorted = SortedArray(sorted: searchable, areInIncreasingOrder: self.sortType.function)
            }

            newFilteredItems[identifier] = sorted
            newSearchableItems[identifier] = searchableSorted
        }

        let newIdentifiers = self.unfilteredIdentifiers.filter { (newFilteredItems[$0]?.count ?? 0) > 0 }

        let newCollection: [ArraySection<String, Model>] = newIdentifiers.map {
            ArraySection(model: $0, elements: newFilteredItems[$0]?.sortedElements ?? [])
        }

        let oldCollection: [ArraySection<String, Model>] = self.identifiers.map {
            ArraySection(model: $0, elements: self.filteredSectionedItems[$0]?.sortedElements ?? [])
        }

        let changeSet = StagedChangeset(source: oldCollection, target: newCollection)

        return (changeSet,
                newIdentifiers,
                self.unfilteredIdentifiers,
                self.models,
                self.sectionedItems,
                newFilteredItems,
                newSearchableItems,
                newFilteredPaths)
    }

    func searchObjects(_ query: String) -> [Model] {

        var found = [Model]()

        for identifier in identifiers {
            let models = self.searchableSectionedItems[identifier]
            if let m = models {
                let a = self.searchModels(m.sortedElements, query: query)
                found += a
            }
        }

        found.removeDuplicates()

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

        return items.sortedElements
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
        return self.filteredIndexPaths[item.differenceIdentifier.hashValue]
    }

    func numberOfItemsInSection(_ section: Int) -> Int {

        guard self.initialized else {
            return 0
        }

        // For SimpleDataSource support as it might request numberOfItemsInSection() without asking numberOfSections()
        guard identifiers.count > section else {
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
        guard self.initialized else {
            fatalError("Data source not initialized yet")
        }
        guard identifiers.count > section else {
            fatalError("Section does not exist")
        }

        let identifier = identifiers[section]
        return identifier
    }
}


//MARK: - Search Data source


public extension SectionDataSource {

    func searchedItemsInSection(_ section: Int) -> [Model] {
        self.foundObjects.sortedElements
    }

    func searchedItemAtIndexPath(_ path: IndexPath) -> Model {
        self.foundObjects[path.row]
    }

    func searchedIndexPath(for item: Model) -> IndexPath? {
        self.foundObjects.firstIndex(of: item).flatMap { IndexPath(item: $0, section: 0) }
    }

    func searchedNumberOfItemsInSection(_ section: Int) -> Int {
        self.foundObjects.count
    }

    func searchedNumberOfSections() -> Int {
        guard self.initialized else {
            return 0
        }
        return 1
    }

    func searchedSectionIdForSection(_ section: Int) -> String {
        SearchSection
    }
}


//MARK: - Search and sort


extension SectionDataSource {

    func sorted(_ unsorted: [Model]) -> [Model] {

        switch self.sortType {
        case .unsorted:
            return unsorted
        case .comparable, .function:
            return unsorted.sorted(by: self.sortType.function)
        }
    }

    func filterModel(_ unfiltered: Model) -> Bool {
        guard let filter = self.filterType else {
            return true
        }

        switch filter {
        case .function, .filterable:
            return filter.function(unfiltered)
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


extension SectionDataSource {
    func prepareChangeSteps(for updateState: UpdateState) -> OrderedChangeSteps {
        self.updateInitial(from: updateState)
        let steps: [ChangeStep] = updateState.changeSet.enumerated().map { (offset, changeSet) in
            let update: () -> Void
            if offset == updateState.changeSet.endIndex - 1 {
                update = { [weak self] in
                    self?.updateFinal(from: updateState)
                }
            } else {
                update = { [weak self] in
                    guard let self = self else { return }
                    self.identifiers = changeSet.data.map { $0.model }
                    self.filteredSectionedItems = Dictionary(uniqueKeysWithValues: changeSet.data.map {
                        ($0.model, SortedArray(sorted: $0.elements, areInIncreasingOrder: self.sortType.function))
                    })
                }
            }
            return ChangeStep(dataSourceUpdate: update,
                              sectionDeleted: changeSet.sectionDeleted,
                              sectionInserted: changeSet.sectionInserted,
                              sectionUpdated: changeSet.sectionUpdated,
                              sectionMoved: changeSet.sectionMoved,
                              elementDeleted: changeSet.elementDeleted.map { IndexPath(item: $0.element, section: $0.section) },
                              elementInserted: changeSet.elementInserted.map { IndexPath(item: $0.element, section: $0.section) },
                              elementUpdated: changeSet.elementUpdated.map { IndexPath(item: $0.element, section: $0.section) },
                              elementMoved: changeSet.elementMoved.map {
                                  (IndexPath(item: $0.element, section: $0.section),
                                   IndexPath(item: $1.element, section: $1.section))
                              })
        }

        return OrderedChangeSteps(steps: ContiguousArray(steps))
    }

    func prepareSearchChangeSteps(for updateState: SearchUpdateState) -> OrderedChangeSteps? {
        guard let changeSets = updateState.changeSet else {
            self.foundObjects = updateState.foundObjects
            return nil
        }
        let steps: [ChangeStep] = changeSets.enumerated().map { (offset, changeSet) in
            let update: () -> Void
            if offset == changeSets.endIndex - 1 {
                update = { [weak self] in
                    self?.foundObjects = updateState.foundObjects
                }
            } else {
                update = { [weak self] in
                    guard let self = self else { return }
                    self.foundObjects = SortedArray(sorted: changeSet.data, areInIncreasingOrder: self.sortType.function)
                }
            }
            return ChangeStep(dataSourceUpdate: update,
                              sectionDeleted: changeSet.sectionDeleted,
                              sectionInserted: changeSet.sectionInserted,
                              sectionUpdated: changeSet.sectionUpdated,
                              sectionMoved: changeSet.sectionMoved,
                              elementDeleted: changeSet.elementDeleted.map { IndexPath(item: $0.element, section: $0.section) },
                              elementInserted: changeSet.elementInserted.map { IndexPath(item: $0.element, section: $0.section) },
                              elementUpdated: changeSet.elementUpdated.map { IndexPath(item: $0.element, section: $0.section) },
                              elementMoved: changeSet.elementMoved.map {
                                  (IndexPath(item: $0.element, section: $0.section),
                                   IndexPath(item: $1.element, section: $1.section))
                              })
        }

        return OrderedChangeSteps(steps: ContiguousArray(steps))
    }
}


//MARK: - Remove object


extension RangeReplaceableCollection where Iterator.Element: Equatable {

    // Remove first collection element that is equal to the given `object`:
    mutating func removeObject(_ object: Iterator.Element) {
        if let index = self.firstIndex(of: object) {
            self.remove(at: index)
        }
    }
}


extension Array where Element: Diffable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element.DifferenceIdentifier: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0.differenceIdentifier) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
