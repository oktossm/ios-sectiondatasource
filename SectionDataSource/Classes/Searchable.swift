//
// Created by Mikhail Mulyar on 08/09/16.
// Copyright (c) 2016 Mikhail Mulyar. All rights reserved.
//

import Foundation


public protocol Searchable {
    func pass(_ query: String) -> Bool
}


extension Searchable {
    public func pass(_ query: String) -> Bool {
        false
    }
}
