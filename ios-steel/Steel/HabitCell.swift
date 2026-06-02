import UIKit
import SnapKit

final class HabitCell: UICollectionViewCell {
    static let reuseID = "HabitCell"

    private let glass = LiquidGlassView(cornerRadius: 22, intensity: .regular)
    private let iconBackdrop = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let categoryBadge = UILabel()
    private let daysLabel = UILabel()
    private let daysCaption = UILabel()
    private let actionButton = UIButton(type: .system)
    private let track = UIView()
    private let fill = UIView()
    private let shimmerView = UIView()
    private var fillWidth: Constraint?
    private var habitCategory: HabitCategory = .bad

    var onRelapse: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.applyCardShadow()
        glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.35)
        contentView.addSubview(glass)
        glass.snp.makeConstraints { $0.edges.equalToSuperview() }

        let content = glass.contentView

        iconBackdrop.layer.cornerRadius = 16
        iconBackdrop.layer.cornerCurve = .continuous
        iconBackdrop.clipsToBounds = true
        content.addSubview(iconBackdrop)
        iconBackdrop.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(18)
            $0.top.equalToSuperview().inset(18)
            $0.width.height.equalTo(42)
        }

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        iconBackdrop.addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }

        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        categoryBadge.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        categoryBadge.textColor = .white
        categoryBadge.textAlignment = .center
        categoryBadge.layer.cornerRadius = 7
        categoryBadge.layer.cornerCurve = .continuous
        categoryBadge.clipsToBounds = true
        content.addSubview(categoryBadge)

        content.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconBackdrop.snp.trailing).offset(12)
            $0.top.equalTo(iconBackdrop).offset(2)
            $0.trailing.lessThanOrEqualTo(categoryBadge.snp.leading).offset(-8)
        }

        categoryBadge.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(18)
            $0.centerY.equalTo(titleLabel)
            $0.height.equalTo(18)
            $0.width.greaterThanOrEqualTo(58)
        }

        daysLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        daysLabel.textColor = .label
        content.addSubview(daysLabel)
        daysLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(18)
            $0.top.equalTo(iconBackdrop.snp.bottom).offset(6)
        }

        daysCaption.font = UIFont.preferredFont(forTextStyle: .caption1)
        daysCaption.textColor = .secondaryLabel
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

        fill.backgroundColor = .systemGreen
        fill.layer.cornerRadius = 4
        track.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            fillWidth = $0.width.equalTo(0).constraint
        }

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
        actionButton.configuration = config
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        content.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(track.snp.bottom).offset(14)
            $0.bottom.lessThanOrEqualToSuperview().inset(16)
            $0.height.equalTo(40)
        }
    }

    func configure(with habit: Habit) {
        habitCategory = habit.category
        iconView.image = UIImage(systemName: habit.iconName)
        titleLabel.text = habit.title

        let tint: UIColor = habit.category == .good ? .systemGreen : .systemRed
        iconBackdrop.backgroundColor = tint

        categoryBadge.text = "  \(habit.category.title.uppercased())  "
        categoryBadge.backgroundColor = tint

        if habit.category == .good {
            let alreadyMarked = habit.isMarkedToday
            daysCaption.text = alreadyMarked ? "дней подряд (✓)" : "дней подряд"
            var cfg = actionButton.configuration ?? UIButton.Configuration.gray()
            cfg.title = alreadyMarked ? "Отмечено сегодня" : "Отметить сегодня"
            cfg.image = UIImage(systemName: alreadyMarked ? "checkmark.seal.fill" : "checkmark.seal")
            cfg.baseForegroundColor = alreadyMarked ? .systemGreen : .systemGreen
            actionButton.configuration = cfg
            actionButton.isEnabled = !alreadyMarked
        } else {
            daysCaption.text = "дней чисто"
            var cfg = actionButton.configuration ?? UIButton.Configuration.gray()
            cfg.title = "Сорвался"
            cfg.image = UIImage(systemName: "arrow.counterclockwise")
            cfg.baseForegroundColor = .label
            actionButton.configuration = cfg
            actionButton.isEnabled = true
        }

        daysLabel.text = "\(habit.cleanDays)"

        let best = max(habit.bestStreak, 30)
        let ratio = best > 0 ? min(1, CGFloat(habit.cleanDays) / CGFloat(best)) : 0

        fillWidth?.update(offset: 0)
        layoutIfNeeded()

        fillWidth?.update(offset: track.bounds.width * ratio)

        UIView.animate(
            withDuration: 2.5,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.1,
            options: .curveEaseOut
        ) {
            self.layoutIfNeeded()
        } completion: { _ in
            if ratio > 0 {
                self.playShimmer()
            }
        }

        if habit.category == .good {
            fill.backgroundColor = ratio >= 1.0 ? .systemGreen : .systemBlue
        } else {
            fill.backgroundColor = ratio >= 1.0 ? .systemGreen : .systemBlue
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

    @objc private func actionTapped() {
        onRelapse?()
    }

    func animateRelapse() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -8, 8, -6, 6, 0]
        shake.duration = 0.4
        glass.layer.add(shake, forKey: "shake")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        shimmerView.isHidden = true
        fillWidth?.update(offset: 0)
        layoutIfNeeded()
    }
}
