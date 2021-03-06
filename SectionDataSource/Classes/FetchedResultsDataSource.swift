//
// Created by Mikhail Mulyar on 25/09/2017.
//

import CoreData


public class FetchedResultsDataSource<Model: NSFetchRequestResult & Diffable>: SimpleDataSource<Model>, NSFetchedResultsControllerDelegate {

    public var ignoreFetchedResultsChanges = false
    public var forceObjectUpdatesFromController = false

    public var fetchRequest: NSFetchRequest<Model> {
        get {
            backingController.fetchRequest
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
            backingController.managedObjectContext
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
    var itemsForForceUpdates = [Model]()

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

        super.init(initialItems: self.backingController.fetchedObjects ?? [Model](),
                   sortType: sortType,
                   filterType: filterType,
                   searchType: searchType,
                   async: async)

        self.backingController.delegate = self
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange anObject: Any,
                           at indexPath: IndexPath?,
                           for type: NSFetchedResultsChangeType,
                           newIndexPath: IndexPath?) {

        switch type {
        case .update:
            if let object = anObject as? Model { self.itemsForForceUpdates.append(object) }
        default:
            break
        }
    }

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.itemsForForceUpdates.removeAll()
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {

        if ignoreFetchedResultsChanges {
            return
        }

        if self.itemsForForceUpdates.isEmpty == false {
            let paths = self.itemsForForceUpdates.compactMap { self.indexPath(for: $0) }
            operationIndex += 1
            self.invokeDelegateUpdate(updates: .update(changes: OrderedChangeSteps(steps: [ChangeStep(dataSourceUpdate: {},
                                                                                                              sectionDeleted: [],
                                                                                                              sectionInserted: [],
                                                                                                              sectionUpdated: [],
                                                                                                              sectionMoved: [],
                                                                                                              elementDeleted: [],
                                                                                                              elementInserted: [],
                                                                                                              elementUpdated: paths,
                                                                                                              elementMoved: [])])),
                                      operationIndex: operationIndex)
            self.itemsForForceUpdates.removeAll()
        }

        fetch()
    }
}
