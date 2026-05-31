import UIKit
import SnapKit

final class HabitCell: UICollectionViewCell {
    static let reuseID = "HabitCell"

    private let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let daysLabel = UILabel()
    private let relapseButton = UIButton(type: .system)
    private let track = UIView()
    private let fill = UIView()
    private var fillWidth: Constraint?

    var onRelapse: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.applyCardShadow()
        glass.layer.cornerRadius = 22
        glass.layer.cornerCurve = .continuous
        glass.clipsToBounds = true
        glass.layer.borderWidth = 0.5
        glass.layer.borderColor = UIColor.separator.cgColor
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
            $0.top.equalTo(iconView.snp.bottom).offset(10)
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
        fill.backgroundColor = .label
        fill.layer.cornerRadius = 4
        track.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            fillWidth = $0.width.equalTo(0).constraint
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
        fillWidth?.update(offset: track.bounds.width * ratio)
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
