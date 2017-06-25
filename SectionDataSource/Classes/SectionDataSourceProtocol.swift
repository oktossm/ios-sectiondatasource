//
// Created by Mikhail Mulyar on 19/06/2017.
// Copyright (c) 2017 Mikhail Mulyar. All rights reserved.
//

import Foundation
import ReactiveSwift
import PaulHeckelDifference
import enum Result.NoError


let SearchSection = "kSearchSection"


public protocol SectionDataSourceProtocol {

    associatedtype Model: Searchable

    // MARK: - Input
    var searchString: MutableProperty<String?> { get }

    // MARK: - Output
    var isSearching:  ReactiveSwift.Property<Bool> { get }

    var contentChangesSignal: Signal<DataSourceUpdates, NoError> { get }

    var searchContentChangesSignal: Signal<DataSourceUpdates, NoError> { get }

    // MARK: - Data source
    func itemAtIndexPath(_ path: IndexPath) -> Model

    func numberOfItemsInSection(_ section: Int) -> Int

    func numberOfSections() -> Int

    func sectionIdForSection(_ section: Int) -> String

    // MARK: - Search Data source
    func searchedItemAtIndexPath(_ path: IndexPath) -> Model

    func searchedNumberOfItemsInSection(_ section: Int) -> Int

    func searchedNumberOfSections() -> Int

    func searchedSectionIdForSection(_ section: Int) -> String
}
