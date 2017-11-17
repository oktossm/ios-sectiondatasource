//
// Created by Mikhail Mulyar on 19/06/2017.
// Copyright (c) 2017 Mikhail Mulyar. All rights reserved.
//

import Foundation
import PaulHeckelDifference


public let SearchSection = "kSearchSection"


public protocol SectionDataSourceProtocol {

    associatedtype Model: Searchable


    // MARK: - Input

    var searchString: String? { get set }

    var filterType: FilterType<Model>? { get set }

    var searchLimit: Int? { get set }

    var limitStep: Int { get set }

    var limit: Int? { get set }

    var searchInterval: TimeInterval { get set }

    func loadMoreData()


    // MARK: - Properties

    var hasMoreData: Bool { get }

    var isSearching: Bool { get }

    var delegate: SectionDataSourceDelegate? { get set }


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
