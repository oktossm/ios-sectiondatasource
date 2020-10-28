//
// Created by Mikhail Mulyar on 08/09/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import Foundation


public protocol Filterable {
    func isIncluded() -> Bool
}


extension Filterable {
    public func isIncluded() -> Bool {
        true
    }
}
