import UIKit
import SnapKit

final class ProgressHeaderView: UICollectionReusableView {
    static let reuseID = "ProgressHeaderView"

    private let label = UILabel()
    private let track = UIView()
    private let fill = UIView()
    private let shimmerView = UIView()
    private var fillWidth: Constraint?
    private var currentRatio: CGFloat = 0

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

        fill.backgroundColor = .systemOrange
        fill.layer.cornerRadius = 5
        track.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            fillWidth = $0.width.equalTo(0).constraint
        }

        // Shimmer effect on fill
        shimmerView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        shimmerView.isHidden = true
        fill.addSubview(shimmerView)
        shimmerView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.width.equalToSuperview()
            $0.leading.equalToSuperview().offset(-bounds.width)
        }
    }

    func configure(done: Int, total: Int, animated: Bool) {
        label.text = "Прогресс  \(done)/\(total)"
        let ratio = total > 0 ? CGFloat(done) / CGFloat(total) : 0

        layoutIfNeeded()
        let targetWidth = track.bounds.width * ratio
        fillWidth?.update(offset: targetWidth)

        if animated {
            // Slow, smooth, luxurious animation
            UIView.animate(withDuration: 2.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut) {
                self.layoutIfNeeded()
            } completion: { _ in
                // Play shimmer effect after fill completes
                if ratio > 0 {
                    self.playShimmer()
                }
            }
        } else {
            layoutIfNeeded()
        }

        // Color based on progress
        if ratio >= 1.0 {
            fill.backgroundColor = .systemGreen
        } else if ratio >= 0.5 {
            fill.backgroundColor = .systemOrange
        } else {
            fill.backgroundColor = .systemOrange
        }

        currentRatio = ratio
    }

    private func playShimmer() {
        shimmerView.isHidden = false
        shimmerView.snp.remakeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.width.equalToSuperview()
            $0.leading.equalToSuperview().offset(-self.fill.bounds.width)
        }
        layoutIfNeeded()

        shimmerView.snp.remakeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.width.equalToSuperview()
            $0.trailing.equalToSuperview()
        }

        UIView.animate(withDuration: 1.2, delay: 0, options: .curveEaseInOut) {
            self.layoutIfNeeded()
        } completion: { _ in
            self.shimmerView.isHidden = true
        }
    }
}
