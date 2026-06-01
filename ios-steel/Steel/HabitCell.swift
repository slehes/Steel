import UIKit
import SnapKit

final class HabitCell: UICollectionViewCell {
    static let reuseID = "HabitCell"

    private let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let daysLabel = UILabel()
    private let daysCaption = UILabel()
    private let relapseButton = UIButton(type: .system)
    private let track = UIView()
    private let fill = UIView()
    private let shimmerView = UIView()
    private var fillWidth: Constraint?

    var onRelapse: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.applyCardShadow()
        glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        glass.layer.cornerRadius = 22
        glass.layer.cornerCurve = .continuous
        glass.clipsToBounds = true
        glass.layer.borderWidth = 0.5
        glass.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        contentView.addSubview(glass)
        glass.snp.makeConstraints { $0.edges.equalToSuperview() }

        let content = glass.contentView

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .label
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        content.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(18)
            $0.top.equalToSuperview().inset(18)
            $0.width.height.equalTo(30)
        }

        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        content.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(12)
            $0.centerY.equalTo(iconView)
            $0.trailing.lessThanOrEqualToSuperview().inset(18)
        }

        daysLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        daysLabel.textColor = .label
        content.addSubview(daysLabel)
        daysLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(18)
            $0.top.equalTo(iconView.snp.bottom).offset(6)
        }

        daysCaption.font = UIFont.preferredFont(forTextStyle: .caption1)
        daysCaption.textColor = .secondaryLabel
        daysCaption.text = "дней чисто"
        content.addSubview(daysCaption)
        daysCaption.snp.makeConstraints {
            $0.leading.equalTo(daysLabel.snp.trailing).offset(6)
            $0.bottom.equalTo(daysLabel.snp.bottom).offset(-4)
        }

        track.backgroundColor = .systemFill
        track.layer.cornerRadius = 4
        track.clipsToBounds = true
        content.addSubview(track)
        track.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(18)
            $0.trailing.equalToSuperview().inset(18)
            $0.top.equalTo(daysLabel.snp.bottom).offset(10)
            $0.height.equalTo(8)
        }

        fill.backgroundColor = .systemOrange
        fill.layer.cornerRadius = 4
        track.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            fillWidth = $0.width.equalTo(0).constraint
        }

        // Shimmer
        shimmerView.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        shimmerView.isHidden = true
        fill.addSubview(shimmerView)
        shimmerView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.width.equalToSuperview()
            $0.leading.equalToSuperview()
        }

        var config = UIButton.Configuration.gray()
        config.title = "Сорвался"
        config.image = UIImage(systemName: "arrow.counterclockwise")
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.cornerStyle = .large
        relapseButton.configuration = config
        relapseButton.addTarget(self, action: #selector(relapseTapped), for: .touchUpInside)
        content.addSubview(relapseButton)
        relapseButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(track.snp.bottom).offset(14)
            $0.bottom.lessThanOrEqualToSuperview().inset(16)
            $0.height.equalTo(40)
        }
    }

    func configure(with habit: Habit) {
        iconView.image = UIImage(systemName: habit.iconName)
        titleLabel.text = habit.title
        daysLabel.text = "\(habit.cleanDays)"

        let best = max(habit.bestStreak, 30)
        let ratio = best > 0 ? min(1, CGFloat(habit.cleanDays) / CGFloat(best)) : 0

        layoutIfNeeded()
        let targetWidth = track.bounds.width * ratio
        fillWidth?.update(offset: targetWidth)

        // Smooth slow animation for fill bar
        UIView.animate(withDuration: 2.0, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: .curveEaseInOut) {
            self.layoutIfNeeded()
        } completion: { _ in
            if ratio > 0 {
                self.playShimmer()
            }
        }

        // Color based on progress
        if ratio >= 1.0 {
            fill.backgroundColor = .systemGreen
        } else if ratio >= 0.5 {
            fill.backgroundColor = .systemOrange
        } else {
            fill.backgroundColor = .systemOrange
        }
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

        UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut) {
            self.layoutIfNeeded()
        } completion: { _ in
            self.shimmerView.isHidden = true
        }
    }

    @objc private func relapseTapped() {
        onRelapse?()
    }

    func animateRelapse() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -8, 8, -6, 6, 0]
        shake.duration = 0.4
        glass.layer.add(shake, forKey: "shake")
    }
}
