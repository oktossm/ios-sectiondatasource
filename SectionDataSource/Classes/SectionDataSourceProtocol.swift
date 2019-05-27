//
// Created by Mikhail Mulyar on 19/06/2017.
// Copyright (c) 2017 Mikhail Mulyar. All rights reserved.
//

import Foundation
import PHDiff


public let SearchSection = "kSearchSection"

public typealias OperationIndex = Int


public protocol SectionDataSourceProtocol {

    associatedtype Model: Diffable, Searchable


    // MARK: - Input

    var searchString: String? { get set }

    var filterType: FilterType<Model>? { get set }

    var sortType: SortType<Model> { get set }

    var searchLimit: Int? { get set }

    var limitStep: Int { get set }

    var limit: Int? { get set }


    // MARK: - Delegate

    var delegate: SectionDataSourceDelegate? { get set }


    // MARK: - Update methods

    @discardableResult
    func update(items: [Model]) -> OperationIndex

    @discardableResult
    func add(item: Model) -> OperationIndex

    @discardableResult
    func update(with diff: [DiffStep<Model>]) -> OperationIndex

    @discardableResult
    func loadMoreData() -> OperationIndex


    // MARK: - Properties

    var allItems: [Model] { get }

    var hasMoreData: Bool { get }

    var isSearching: Bool { get }


    // MARK: - Data source

    func itemsInSection(_ section: Int) -> [Model]

    func itemAtIndexPath(_ path: IndexPath) -> Model

    func indexPath(for item: Model) -> IndexPath?

    func numberOfItemsInSection(_ section: Int) -> Int

    func numberOfSections() -> Int

    func sectionIdForSection(_ section: Int) -> String


    // MARK: - Search Data source

    func searchedItemsInSection(_ section: Int) -> [Model]

    func searchedItemAtIndexPath(_ path: IndexPath) -> Model

    func searchedIndexPath(for item: Model) -> IndexPath?

    func searchedNumberOfItemsInSection(_ section: Int) -> Int

    func searchedNumberOfSections() -> Int

    func searchedSectionIdForSection(_ section: Int) -> String
}
