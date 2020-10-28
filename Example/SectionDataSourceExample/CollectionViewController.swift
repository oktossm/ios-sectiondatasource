import UIKit
import SectionDataSource


class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, SectionDataSourceDelegate {

    var collectionView: UICollectionView!
    let dataSource = SectionDataSource<RandomContent>(initialItems: [],
                                                      sectionFunction: {
                                                          if Int.random(in: 0..<5) == 0 {
                                                              return ["***"]
                                                          }

                                                          return [String("\($0.differenceIdentifier)".prefix(1)) + "*",
                                                                  "*" + String("\($0.differenceIdentifier)".suffix(1))]
                                                      },
                                                      sortType: .function(function: { $0.differenceIdentifier < $1.differenceIdentifier }))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white

        title = "Collection"

        self.dataSource.delegate = self

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        collectionView.backgroundColor = .white
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(collectionView)

        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        collectionView.register(CollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.register(RandomLabelView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "Header")
        navigationItem.rightBarButtonItems = [UIBarButtonItem(
            title: "Update", style: .plain, target: self, action: #selector(update)
        ), UIBarButtonItem(
            title: "Reload", style: .plain, target: self, action: #selector(reload)
        )]
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Benchmark", style: .plain, target: self, action: #selector(benchmarkSelf)
        )
    }

    @objc func update() {
        dataSource.update(items: DataSet.generateRandomlyEquatableItems())
    }

    @objc func reload() {
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItemsInSection(section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! CollectionViewCell
        let item = dataSource.itemAtIndexPath(indexPath)

        cell.label.text = "\(item.differenceIdentifier)"

        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        let model = dataSource.sectionIdForSection(indexPath.section)
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader,
                                                                   withReuseIdentifier: "Header",
                                                                   for: indexPath)

        if let labelView = view as? RandomLabelView {
            labelView.label.text = "Section ID: \(model)"
        }

        return view
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        CGSize(width: self.view.frame.size.width, height: 50)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        CGSize(width: 50, height: 50)
    }


    func dataSource<T: Searchable>(_ dataSource: SectionDataSource<T>, didUpdateContent updates: DataSourceUpdates, operationIndex: Int) {
        print(updates)
        let exception = tryBlock {
            switch updates {
            case .initial(let changes):
                self.collectionView.reload(using: changes)
            case .update(let changes):
                self.collectionView.reload(using: changes)
            default:
                break
            }
        }

        if let exception = exception {
            print(exception as Any)
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


final class RandomLabelView: UICollectionReusableView {
    var label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.label.textColor = .darkText
        self.backgroundColor = .lightGray

        self.addSubview(label)
    }

    override var frame: CGRect {
        didSet {
            label.frame = self.bounds
        }
    }

    override required init?(coder: NSCoder) {
        super.init(coder: coder)

        self.label.textColor = .darkText
        self.backgroundColor = .lightGray
    }
}
