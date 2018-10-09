import UIKit
import SectionDataSource


class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, SectionDataSourceDelegate {

    var collectionView: UICollectionView!
    let dataSource = SimpleDataSource<Int>(initialItems: [], sortType: .function(function: <))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white

        title = "CollectionView"

        self.dataSource.delegate = self

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 15, left: 15, bottom: 10, right: 15)
        collectionView.backgroundColor = .white
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(collectionView)

        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        collectionView.register(CollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Reload", style: .plain, target: self, action: #selector(reload)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Benchmark", style: .plain, target: self, action: #selector(benchmarkSelf)
        )
    }

    @objc func reload() {
        dataSource.update(items: DataSet.generateItems())
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! CollectionViewCell
        let item = dataSource.itemAtIndexPath(indexPath)

        cell.label.text = "\(item)"

        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let size = collectionView.frame.size.width / 5
        return CGSize(width: size, height: size)
    }

    func dataSource<T: Searchable>(_ dataSource: SectionDataSource<T>, didUpdateContent updates: DataSourceUpdates, operationIndex: Int) {
        let exception = tryBlock {
            self.collectionView.performBatchUpdates(
                    {
                        switch updates {
                        case .initial(let changes):
                            changes.update(collectionView: self.collectionView)
                        case .update(let changes):
                            changes.update(collectionView: self.collectionView)
                        default:
                            break
                        }
                    },
                    completion: {
                        finished in
                    })
        }

        if let exception = exception {
            print(exception as Any)
            print(updates)
        }
    }

    @objc private func benchmarkSelf() {

        var (old, new) = generate(count: 10000, removeRange: 1000..<2000, addRange: 5000..<7000)
        var dataSource = SimpleDataSource<String>(initialItems: old, sortType: .function(function: <), async: false)
        benchmark(name: "10000", closure: {
            dataSource.update(items: new)
        })

        (old, new) = generate(count: 20000, removeRange: 2000..<4000, addRange: 10000..<14000)
        dataSource = SimpleDataSource<String>(initialItems: old, sortType: .function(function: <), async: false)
        benchmark(name: "20000", closure: {
            dataSource.update(items: new)
        })

        (old, new) = generate(count: 50000, removeRange: 5000..<10000, addRange: 10000..<15000)
        dataSource = SimpleDataSource<String>(initialItems: old, sortType: .function(function: <), async: false)
        benchmark(name: "50000", closure: {
            dataSource.update(items: new)
        })
    }

    private func benchmark(name: String, closure: () -> Void) {
        let start = Date()
        closure()
        let end = Date()

        print("\(name): \(end.timeIntervalSince1970 - start.timeIntervalSince1970)s")
    }

    // Generate old and new
    func generate(
            count: Int,
            removeRange: Range<Int>? = nil,
            addRange: Range<Int>? = nil)
                    -> (old: Array<String>, new: Array<String>) {

        let old = Array(repeating: UUID().uuidString, count: count)
        var new = old

        if let removeRange = removeRange {
            new.removeSubrange(removeRange)
        }

        if let addRange = addRange {
            new.insert(
                    contentsOf: Array(repeating: UUID().uuidString, count: addRange.count),
                    at: addRange.lowerBound
            )
        }

        return (old: old, new: new)
    }
}
