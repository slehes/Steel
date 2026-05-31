import UIKit
import SnapKit

final class ProgressHeaderView: UICollectionReusableView {
    static let reuseID = "ProgressHeaderView"

    private let label = UILabel()
    private let track = UIView()
    private let fill = UIView()
    private var fillWidth: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        addSubview(label)
        label.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
        }

        track.backgroundColor = .systemFill
        track.layer.cornerRadius = 5
        track.clipsToBounds = true
        addSubview(track)
        track.snp.makeConstraints {
            $0.top.equalTo(label.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(10)
            $0.bottom.equalToSuperview().inset(8)
        }

        fill.backgroundColor = .label
        fill.layer.cornerRadius = 5
        track.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            fillWidth = $0.width.equalTo(0).constraint
        }
    }

    func configure(done: Int, total: Int) {
        label.text = "Прогресс  \(done)/\(total)"
        let ratio = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        layoutIfNeeded()
        fillWidth?.update(offset: track.bounds.width * ratio)
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
            self.layoutIfNeeded()
        }
    }
}
