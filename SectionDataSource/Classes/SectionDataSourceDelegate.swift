//
// Created by Mikhail Mulyar on 17/11/2017.
//

import PaulHeckelDifference


public protocol SectionDataSourceDelegate: class {
    func dataSource<T: Diffable>(_ dataSource: SectionDataSource<T>, didUpdateContent updates: DataSourceUpdates, operationIndex: OperationIndex)
    func dataSource<T: Diffable>(_ dataSource: SectionDataSource<T>, didUpdateSearchContent updates: DataSourceUpdates)
    func dataSource<T: Diffable>(_ dataSource: SectionDataSource<T>, didUpdateSearchState isSearching: Bool)
}


extension SectionDataSourceDelegate {
    public func dataSource<T: Diffable>(_ dataSource: SectionDataSource<T>, didUpdateSearchContent updates: DataSourceUpdates) {

    }

    public func dataSource<T: Diffable>(_ dataSource: SectionDataSource<T>, didUpdateSearchState isSearching: Bool) {

    }
}