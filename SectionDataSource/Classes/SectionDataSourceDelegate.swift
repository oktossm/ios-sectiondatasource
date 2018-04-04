//
// Created by Mikhail Mulyar on 17/11/2017.
//

import PaulHeckelDifference


public protocol SectionDataSourceDelegate: class {
    func dataSource<T: Searchable>(_ dataSource: SectionDataSource<T>, didUpdateContent updates: DataSourceUpdates)
    func dataSource<T: Searchable>(_ dataSource: SectionDataSource<T>, didUpdateSearchContent updates: DataSourceUpdates)
    func dataSource<T: Searchable>(_ dataSource: SectionDataSource<T>, didUpdateSearchState isSearching: Bool)
}