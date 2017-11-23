//
// Created by Mikhail Mulyar on 17/11/2017.
//

import PaulHeckelDifference


public protocol SectionDataSourceDelegate {

    func contentDidUpdate(updates: DataSourceUpdates)

    func searchContentDidUpdate(updates: DataSourceUpdates)

    func didUpdateSearchState(isSearching: Bool)
}