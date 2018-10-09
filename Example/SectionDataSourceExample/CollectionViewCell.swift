import UIKit
import Hue


class CollectionViewCell: UICollectionViewCell {
    let label = UILabel()

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        label.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        backgroundColor = UIColor(hex: "#e67e22")
        layer.cornerRadius = 5
        layer.masksToBounds = true

        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .white
    }
}
