import UIKit
import XCTest
import PaulHeckelDifference
@testable import SectionDataSource


struct TestModel: Diffable, Searchable, CustomDebugStringConvertible {

    let identifier: String
    var value: String

    init(identifier: String, value: String) {
        self.identifier = identifier
        self.value = value
    }

    func pass(_ query: String) -> Bool {
        return identifier.hasPrefix(query)
    }

    public var diffIdentifier: String {
        return identifier
    }
    public var debugDescription: String {
        return "Model: \(self.identifier)"
    }
}


func ==(lhs: TestModel, rhs: TestModel) -> Bool {
    return lhs.value == rhs.value && lhs.identifier == rhs.identifier
}


final class MockedSimpleDataSource<Model: Diffable & Searchable>: SimpleDataSource<Model> {

    var contentExpectationBlock: ((DataSourceUpdates) -> Void)?
    var searchContentExpectationBlock: ((DataSourceUpdates) -> Void)?

    override func invokeDelegateUpdate(updates: DataSourceUpdates, operationIndex: OperationIndex) {
        self.contentExpectationBlock?(updates)
    }

    override func invokeSearchDelegateUpdate(updates: DataSourceUpdates) {
        self.searchContentExpectationBlock?(updates)
    }
}


final class MockedSectionDataSource<Model: Diffable & Searchable>: SectionDataSource<Model> {

    var contentExpectationBlock: ((DataSourceUpdates) -> Void)?
    var searchContentExpectationBlock: ((DataSourceUpdates) -> Void)?

    override func invokeDelegateUpdate(updates: DataSourceUpdates, operationIndex: OperationIndex) {
        self.contentExpectationBlock?(updates)
    }

    override func invokeSearchDelegateUpdate(updates: DataSourceUpdates) {
        self.searchContentExpectationBlock?(updates)
    }
}


final class Tests: XCTestCase {

    var linkedDataSource: MockedSimpleDataSource<TestModel>?
    var linkedSectionDataSource: MockedSectionDataSource<TestModel>?

    static func unsortedDataSource(_ models: [TestModel]) -> MockedSimpleDataSource<TestModel> {
        return MockedSimpleDataSource(initialItems: models,
                                      sortType: .unsorted)
    }

    static func syncDataSource(_ models: [TestModel]) -> MockedSimpleDataSource<TestModel> {
        return MockedSimpleDataSource(initialItems: models,
                                      sortType: .unsorted,
                                      async: false)
    }

    static func syncSectionedDataSource(_ models: [TestModel]) -> MockedSectionDataSource<TestModel> {
        return MockedSectionDataSource(initialItems: models,
                                       sectionFunction: { (model) -> (String) in return String(model.value.first ?? Character("1")) },
                                       sectionType: .sorting(function: { $0 < $1 }),
                                       sortType: .function { $0.identifier < $1.identifier },
                                       async: false)
    }

    static func simpleDataSource(_ models: [TestModel]) -> MockedSimpleDataSource<TestModel> {
        return MockedSimpleDataSource(initialItems: models,
                                      sortType: .function { $0.identifier < $1.identifier })
    }

    static func prefilledDataSource(_ models: [TestModel]) -> MockedSectionDataSource<TestModel> {
        return MockedSectionDataSource(initialItems: models,
                                       sectionFunction: { (model) -> (String) in return String(model.value.first ?? Character("1")) },
                                       sectionType: .prefilled(sections: ["1", "2", "3", "4"]),
                                       sortType: .function { $0.identifier < $1.identifier })
    }

    static func sectionedDataSource(_ models: [TestModel]) -> MockedSectionDataSource<TestModel> {
        return MockedSectionDataSource(initialItems: models,
                                       sectionFunction: { (model) -> (String) in return String(model.value.first ?? Character("1")) },
                                       sectionType: .sorting(function: { $0 < $1 }),
                                       sortType: .function { $0.identifier < $1.identifier })
    }

    static func sectionedUnsortedDataSource(_ models: [TestModel]) -> MockedSectionDataSource<TestModel> {
        return MockedSectionDataSource(initialItems: models,
                                       sectionFunction: { (model) -> (String) in return String(model.value.first ?? Character("1")) },
                                       sectionType: .sorting(function: { $0 < $1 }),
                                       sortType: .unsorted)
    }

    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSimpleSetup() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.simpleDataSource([TestModel(identifier: "a", value: "1")])

        dataSource.contentExpectationBlock = {
            updates in
            guard case .initial = updates else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testSetup() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.prefilledDataSource([TestModel(identifier: "a", value: "1")])

        dataSource.contentExpectationBlock = {
            updates in
            guard case .initial(let changes) = updates, changes.sectionsDiffSteps.inserts.count > 0 else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testInsert() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.simpleDataSource([TestModel(identifier: "a", value: "1")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            guard case .update(let changes) = updates,
                  let insert = changes.inserts.first,
                  insert == 0
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "b", value: "1")])

        wait(for: [expectation], timeout: 1)
    }

    func testUpdate() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.simpleDataSource([TestModel(identifier: "a", value: "3"),
                                                 TestModel(identifier: "b", value: "1")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            guard case .update(let changes) = updates,
                  changes.updates.count == 2,
                  changes.updates.contains(where: { $0.0 == $0.1 && $0.0 == 0 }),
                  changes.updates.contains(where: { $0.0 == $0.1 && $0.0 == 1 })
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "a", value: "1"),
                                  TestModel(identifier: "b", value: "2")])

        wait(for: [expectation], timeout: 1)
    }

    func testDelete() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.simpleDataSource([TestModel(identifier: "a", value: "3"),
                                                 TestModel(identifier: "b", value: "1")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            guard case .update(let changes) = updates,
                  changes.deletes.count == 1,
                  changes.deletes.contains(where: { $0 == 0 })
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "b", value: "1")])

        wait(for: [expectation], timeout: 1)
    }

    func testMove() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.unsortedDataSource([TestModel(identifier: "a", value: "1"),
                                                   TestModel(identifier: "b", value: "1"),
                                                   TestModel(identifier: "c", value: "1")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            guard case .update(let changes) = updates,
                  changes.moves.count == 3
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "b", value: "1"),
                                  TestModel(identifier: "c", value: "1"),
                                  TestModel(identifier: "a", value: "1")])

        wait(for: [expectation], timeout: 1)
    }

    func testFilter() {

        let expectation = XCTestExpectation()

        linkedDataSource = Tests.unsortedDataSource([TestModel(identifier: "a", value: "1"),
                                                     TestModel(identifier: "b", value: "2"),
                                                     TestModel(identifier: "c", value: "1")])

        linkedDataSource?.contentExpectationBlock = {
            [weak self] updates in

            if case .initial = updates {
                self?.linkedDataSource?.filterType = .function {
                    model in
                    return model.value == "1"
                }
                return
            }

            guard case .update(let changes) = updates,
                  changes.deletes.count == 1,
                  changes.deletes.first == 1
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testSorting() {

        let expectation = XCTestExpectation()

        linkedDataSource = Tests.unsortedDataSource([TestModel(identifier: "a", value: "1"),
                                                     TestModel(identifier: "b", value: "2"),
                                                     TestModel(identifier: "c", value: "1")])

        linkedDataSource?.contentExpectationBlock = {
            [weak self] updates in

            if case .initial = updates {
                self?.linkedDataSource?.sortType = .function {
                    m1, m2 in
                    return (Int(m1.value) ?? 0) < (Int(m2.value) ?? 0)
                }
                return
            }

            guard case .update(let changes) = updates,
                  changes.moves.count == 2,
                  let move = changes.moves.first,
                  (move.fromIndex == 2 && move.toIndex == 1) || (move.fromIndex == 1 && move.toIndex == 2)
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testComplex() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.unsortedDataSource([TestModel(identifier: "a", value: "1"),
                                                   TestModel(identifier: "b", value: "5"),
                                                   TestModel(identifier: "c", value: "3")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            XCTAssertTrue(Thread.isMainThread)

            guard case .update(let changes) = updates,
                  changes.moves.filter({ $0.fromIndex != $0.toIndex }).count == 2,
                  changes.updates.count == 1,
                  changes.updates.first?.oldIndex == 1,
                  changes.updates.first?.newIndex == 0,
                  changes.inserts.count == 1,
                  changes.inserts.first == 3
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "b", value: "2"),
                                  TestModel(identifier: "a", value: "1"),
                                  TestModel(identifier: "c", value: "3"),
                                  TestModel(identifier: "d", value: "4")])

        wait(for: [expectation], timeout: 1)
    }

    func testSectionsUpdates() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.sectionedDataSource([TestModel(identifier: "a", value: "1"),
                                                    TestModel(identifier: "b", value: "1"),
                                                    TestModel(identifier: "c", value: "1"),
                                                    TestModel(identifier: "d", value: "2"),
                                                    TestModel(identifier: "e", value: "2"),
                                                    TestModel(identifier: "f", value: "3")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            guard case .update(let changes) = updates,
                  changes.sectionsDiffSteps.inserts.count == 1,
                  changes.sectionsDiffSteps.inserts.first == 2,
                  changes.sectionsDiffSteps.deletes.count == 1,
                  changes.sectionsDiffSteps.deletes.first == 2,
                  changes.itemsDiffSteps.count == 3
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }

            XCTAssertTrue(dataSource.numberOfItemsInSection(0) == 2, "\(updates)")
            XCTAssertTrue(dataSource.numberOfItemsInSection(1) == 2, "\(updates)")
            XCTAssertTrue(dataSource.numberOfItemsInSection(2) == 1, "\(updates)")
            XCTAssertTrue(dataSource.numberOfSections() == 3, "\(updates)")

            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "a", value: "2"),
                                  TestModel(identifier: "b", value: "1"),
                                  TestModel(identifier: "c", value: "2"),
                                  TestModel(identifier: "d", value: "1"),
                                  TestModel(identifier: "e", value: "4")])

        wait(for: [expectation], timeout: 1)
    }

    func testSectionsPrefilledUpdates() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.prefilledDataSource([TestModel(identifier: "a", value: "1"),
                                                    TestModel(identifier: "b", value: "1"),
                                                    TestModel(identifier: "c", value: "1"),
                                                    TestModel(identifier: "d", value: "2"),
                                                    TestModel(identifier: "e", value: "2"),
                                                    TestModel(identifier: "f", value: "3")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            guard case .update(let changes) = updates,
                  changes.sectionsDiffSteps.inserts.count == 0,
                  changes.sectionsDiffSteps.deletes.count == 0,
                  changes.sectionsDiffSteps.moves.count == 0
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }

            XCTAssertTrue(dataSource.numberOfItemsInSection(0) == 2, "\(updates)")
            XCTAssertTrue(dataSource.numberOfItemsInSection(1) == 2, "\(updates)")
            XCTAssertTrue(dataSource.numberOfItemsInSection(2) == 0, "\(updates)")
            XCTAssertTrue(dataSource.numberOfItemsInSection(3) == 1, "\(updates)")
            XCTAssertTrue(dataSource.numberOfSections() == 4, "\(updates)")

            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "a", value: "2"),
                                  TestModel(identifier: "b", value: "1"),
                                  TestModel(identifier: "c", value: "2"),
                                  TestModel(identifier: "d", value: "1"),
                                  TestModel(identifier: "e", value: "4")])

        wait(for: [expectation], timeout: 1)
    }

    func testSearch() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.simpleDataSource([TestModel(identifier: "a", value: "3"),
                                                 TestModel(identifier: "b", value: "1")])

        dataSource.searchContentExpectationBlock = {
            [unowned dataSource] updates in

            guard case .reload = updates,
                  dataSource.searchedNumberOfItemsInSection(0) == 1,
                  dataSource.searchedItemAtIndexPath(IndexPath(row: 0, section: 0)) == TestModel(identifier: "a", value: "3")
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.searchString = "a"

        wait(for: [expectation], timeout: 1)
    }

    func testComplexSearch() {

        let expectation = XCTestExpectation()

        self.linkedDataSource = Tests.simpleDataSource([TestModel(identifier: "a", value: "3"),
                                                        TestModel(identifier: "b", value: "1")])

        self.linkedDataSource?.searchContentExpectationBlock = {
            [unowned self] updates in

            if case .reload = updates {
                self.linkedDataSource?.searchString = "b"
                return
            }
            guard case .update(let changes) = updates,
                  changes.inserts.count == 1,
                  changes.deletes.count == 1,
                  let insert = changes.inserts.first,
                  insert == 0
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        self.linkedDataSource?.searchString = "a"

        wait(for: [expectation], timeout: 2)
    }

    func testComplexSectionSearch() {

        let expectation = XCTestExpectation()

        self.linkedSectionDataSource = Tests.sectionedDataSource([TestModel(identifier: "a", value: "1"),
                                                                  TestModel(identifier: "b", value: "1"),
                                                                  TestModel(identifier: "c", value: "1"),
                                                                  TestModel(identifier: "d", value: "2"),
                                                                  TestModel(identifier: "ad", value: "2"),
                                                                  TestModel(identifier: "af", value: "3")])

        self.linkedSectionDataSource?.searchContentExpectationBlock = {
            [unowned self] updates in

            if case .reload = updates {
                self.linkedSectionDataSource?.searchString = "a"
                return
            }
            guard case .update(let changes) = updates,
                  changes.inserts.count == 3,
                  changes.deletes.count == 1,
                  let insert = changes.inserts.first,
                  insert == 0
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        self.linkedSectionDataSource?.searchString = "b"

        wait(for: [expectation], timeout: 2)
    }

    func testIndexPaths() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.sectionedDataSource([TestModel(identifier: "a", value: "1"),
                                                    TestModel(identifier: "b", value: "1"),
                                                    TestModel(identifier: "c", value: "1"),
                                                    TestModel(identifier: "d", value: "2"),
                                                    TestModel(identifier: "e", value: "2"),
                                                    TestModel(identifier: "f", value: "3")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            for section in 0..<dataSource.numberOfSections() {
                let items = dataSource.itemsInSection(section)
                for item in items {
                    guard let indexPath = dataSource.indexPath(for: item) else {
                        XCTAssertTrue(false)
                        continue
                    }
                    let model = dataSource.itemAtIndexPath(indexPath)
                    XCTAssertTrue(item.diffIdentifier == model.diffIdentifier)
                }
            }

            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "a", value: "2"),
                                  TestModel(identifier: "b", value: "1"),
                                  TestModel(identifier: "c", value: "2"),
                                  TestModel(identifier: "d", value: "1"),
                                  TestModel(identifier: "e", value: "4"),
                                  TestModel(identifier: "f", value: "4"),
                                  TestModel(identifier: "g", value: "3"),
                                  TestModel(identifier: "h", value: "3"),
                                  TestModel(identifier: "i", value: "3"),
                                  TestModel(identifier: "g", value: "4"),
                                  TestModel(identifier: "k", value: "4"),
                                  TestModel(identifier: "m", value: "2"),
                                  TestModel(identifier: "n", value: "1"),
                                  TestModel(identifier: "o", value: "1"),
                                  TestModel(identifier: "p", value: "4"),
                                  TestModel(identifier: "u", value: "4")])

        wait(for: [expectation], timeout: 1)
    }

    func testSyncUpdates() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.syncDataSource([TestModel(identifier: "a", value: "1"),
                                               TestModel(identifier: "b", value: "5"),
                                               TestModel(identifier: "c", value: "3"),
                                               TestModel(identifier: "d", value: "3"),
                                               TestModel(identifier: "e", value: "3"),
                                               TestModel(identifier: "g", value: "3"),
                                               TestModel(identifier: "k", value: "3"),
                                               TestModel(identifier: "n", value: "3"),
                                               TestModel(identifier: "v", value: "3")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            XCTAssertTrue(Thread.isMainThread)

            guard case .update(let changes) = updates,
                  changes.moves.filter({ $0.fromIndex != $0.toIndex }).count == 4,
                  changes.updates.count == 5,
                  changes.inserts.count == 4
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "b", value: "2"),
                                  TestModel(identifier: "a", value: "1"),
                                  TestModel(identifier: "c", value: "3"),
                                  TestModel(identifier: "d", value: "4"),
                                  TestModel(identifier: "v", value: "4"),
                                  TestModel(identifier: "m", value: "4"),
                                  TestModel(identifier: "n", value: "4"),
                                  TestModel(identifier: "l", value: "4"),
                                  TestModel(identifier: "k", value: "4"),
                                  TestModel(identifier: "p", value: "4"),
                                  TestModel(identifier: "q", value: "4")])

        XCTAssertTrue(dataSource.numberOfItemsInSection(0) == 11)

        wait(for: [expectation], timeout: 1)
    }

    func testAsyncUpdates() {

        let expectation = XCTestExpectation()

        let dataSource = Tests.unsortedDataSource([TestModel(identifier: "a", value: "1"),
                                                   TestModel(identifier: "b", value: "5"),
                                                   TestModel(identifier: "c", value: "3"),
                                                   TestModel(identifier: "d", value: "3"),
                                                   TestModel(identifier: "e", value: "3"),
                                                   TestModel(identifier: "g", value: "3"),
                                                   TestModel(identifier: "k", value: "3"),
                                                   TestModel(identifier: "n", value: "3"),
                                                   TestModel(identifier: "v", value: "3")])

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            XCTAssertTrue(Thread.isMainThread)

            guard case .update(let changes) = updates,
                  changes.moves.filter({ $0.fromIndex != $0.toIndex }).count == 4,
                  changes.updates.count == 5,
                  changes.inserts.count == 4
                else {
                XCTAssertTrue(false, "\(updates)")
                return
            }
            expectation.fulfill()
        }

        dataSource.update(items: [TestModel(identifier: "b", value: "2"),
                                  TestModel(identifier: "a", value: "1"),
                                  TestModel(identifier: "c", value: "3"),
                                  TestModel(identifier: "d", value: "4"),
                                  TestModel(identifier: "v", value: "4"),
                                  TestModel(identifier: "m", value: "4"),
                                  TestModel(identifier: "n", value: "4"),
                                  TestModel(identifier: "l", value: "4"),
                                  TestModel(identifier: "k", value: "4"),
                                  TestModel(identifier: "p", value: "4"),
                                  TestModel(identifier: "q", value: "4")])

        wait(for: [expectation], timeout: 1)
    }

    func testIndexPathsRandom() {
        let oldArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }
        let newArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }

        let expectation = XCTestExpectation()

        let dataSource = Tests.unsortedDataSource(oldArray)

        dataSource.contentExpectationBlock = {
            updates in

            if case .initial = updates { return }

            for section in 0..<dataSource.numberOfSections() {
                let items = dataSource.itemsInSection(section)
                for item in items {
                    guard let indexPath = dataSource.indexPath(for: item) else {
                        XCTAssertTrue(false)
                        continue
                    }
                    let model = dataSource.itemAtIndexPath(indexPath)
                    XCTAssertTrue(item.diffIdentifier == model.diffIdentifier)
                }
            }

            expectation.fulfill()
        }

        dataSource.update(items: newArray)

        self.wait(for: [expectation], timeout: 1)
    }

    func testAsyncPerformance() {
        let oldArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }
        let newArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }

        self.measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {

            let expectation = XCTestExpectation()

            self.startMeasuring()

            self.linkedDataSource = Tests.unsortedDataSource(oldArray)

            self.linkedDataSource?.contentExpectationBlock = {
                updates in

                if case .initial = updates { return }

                self.stopMeasuring()
                expectation.fulfill()
            }

            self.linkedDataSource?.update(items: newArray)

            self.wait(for: [expectation], timeout: 1)
        }
    }

    func testSimpleUnsortedPerformance() {

        let oldArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }
        let newArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }

        self.measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {

            let dataSource = Tests.syncDataSource(oldArray)

            self.startMeasuring()
            let _ = dataSource.update(for: newArray)
            self.stopMeasuring()
        }
    }

    func testSectionedUnsortedPerformance() {

        let oldArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }
        let newArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }

        self.measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {

            let dataSource = Tests.sectionedUnsortedDataSource(oldArray)

            self.startMeasuring()
            let _ = dataSource.update(for: newArray)
            self.stopMeasuring()
        }
    }

    func testSimplePerformance() {

        let oldArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }
        let newArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }

        self.measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {

            let dataSource = Tests.simpleDataSource(oldArray)

            self.startMeasuring()
            let _ = dataSource.update(for: newArray)
            self.stopMeasuring()
        }
    }

    func testSectionedPerformance() {

        let oldArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }
        let newArray = randomArray(length: 1000).map { TestModel(identifier: $0, value: String(randomNumber(0..<20))) }

        self.measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {

            let dataSource = Tests.syncSectionedDataSource(oldArray)

            self.startMeasuring()
            let _ = dataSource.update(for: newArray)
            self.stopMeasuring()
        }
    }
}


func randomArray(length: Int) -> [String] {
    let charactersString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let charactersArray: [Character] = Array(charactersString)

    var array: [String] = []
    for _ in 0..<length {
        array.append(String(charactersArray[Int(arc4random()) % charactersArray.count]))
    }

    return array
}

func randomNumber(_ range: Range<Int>) -> Int {
    let min = range.lowerBound
    let max = range.upperBound
    return Int(arc4random_uniform(UInt32(max - min))) + min
}
