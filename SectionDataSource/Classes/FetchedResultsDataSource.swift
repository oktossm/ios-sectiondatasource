//
// Created by Mikhail Mulyar on 25/09/2017.
//

import Foundation
import CoreData
import ReactiveSwift
import enum Result.NoError


public class FetchedResultsDataSource<Model:NSManagedObject & Searchable>: SimpleDataSource<Model>, NSFetchedResultsControllerDelegate {

    public var ignoreFetchedResultsChanges = false

    public var fetchRequest: NSFetchRequest<Model> {
        get {
            return backingController.fetchRequest
        }
        set {
            if fetchRequest.isEqual(newValue) || self.initialized == false {
                return
            }

            self.backingController = NSFetchedResultsController(fetchRequest: newValue,
                                                                managedObjectContext: managedObjectContext,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
            self.backingController.delegate = self

            try? self.backingController.performFetch()

            self.update(items: self.backingController.fetchedObjects ?? [Model]())
        }
    }

    public var managedObjectContext: NSManagedObjectContext {
        get {
            return backingController.managedObjectContext
        }
        set {
            if managedObjectContext.isEqual(newValue) || self.initialized == false {
                return
            }
            self.backingController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                managedObjectContext: newValue,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
            self.backingController.delegate = self

            try? self.backingController.performFetch()

            self.update(items: self.backingController.fetchedObjects ?? [Model]())
        }
    }

    public func fetch() {
        self.update(items: self.backingController.fetchedObjects ?? [Model]())
    }


    var backingController: NSFetchedResultsController<Model>
    var fetchedChangesSignal: Signal<Void, NoError>
    var fetchedChangesObserver: Observer<Void, NoError>

    public init(fetchRequest: NSFetchRequest<Model>,
                managedObjectContext: NSManagedObjectContext,
                sortType: SortType<Model>,
                filterType: FilterType<Model>? = nil,
                searchType: SearchType<Model> = .searchable,
                async: Bool = true) {

        self.backingController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                            managedObjectContext: managedObjectContext,
                                                            sectionNameKeyPath: nil,
                                                            cacheName: nil)
        try? self.backingController.performFetch()

        (self.fetchedChangesSignal, self.fetchedChangesObserver) = Signal<Void, NoError>.pipe()

        super.init(initialItems: self.backingController.fetchedObjects ?? [Model](),
                   sortType: sortType,
                   filterType: filterType,
                   searchType: searchType,
                   async: async)

        self.backingController.delegate = self
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {

        if ignoreFetchedResultsChanges {
            return
        }

        fetch()
    }
}
