import UIKit
import SnapKit
import Lottie

final class TaskCell: UICollectionViewCell {
    static let reuseID = "TaskCell"

    private let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let lottieView = LottieAnimationView(name: "success")

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.applyCardShadow()

        glass.layer.cornerRadius = 22
        glass.layer.cornerCurve = .continuous
        glass.clipsToBounds = true
        glass.layer.borderWidth = 0.5
        glass.layer.borderColor = UIColor.separator.cgColor
        contentView.addSubview(glass)
        glass.snp.makeConstraints { $0.edges.equalToSuperview() }

        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        iconView.tintColor = .label

        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .label

        detailLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel

        let content = glass.contentView
        content.addSubview(iconView)
        content.addSubview(titleLabel)
        content.addSubview(detailLabel)

        iconView.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(18)
            $0.width.height.equalTo(34)
        }
        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(18)
            $0.trailing.equalToSuperview().inset(12)
            $0.top.equalTo(iconView.snp.bottom).offset(14)
        }
        detailLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(18)
            $0.trailing.equalToSuperview().inset(12)
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.bottom.lessThanOrEqualToSuperview().inset(16)
        }

        lottieView.contentMode = .scaleAspectFit
        lottieView.isUserInteractionEnabled = false
        content.addSubview(lottieView)
        lottieView.snp.makeConstraints {
            $0.center.equalTo(iconView)
            $0.width.height.equalTo(90)
        }
    }

    override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {
            super.isHighlighted = newValue
            UIView.animate(withDuration: 0.1) {
                self.glass.alpha = newValue ? 0.6 : 1.0
            }
        }
    }

    func configure(with task: DailyTask) {
        iconView.image = UIImage(systemName: task.isCompleted ? "checkmark.circle.fill" : task.iconName)
        iconView.tintColor = task.isCompleted ? .systemGreen : .label

        let attributes: [NSAttributedString.Key: Any] = task.isCompleted
            ? [.strikethroughStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: UIColor.secondaryLabel]
            : [.foregroundColor: UIColor.label]
        titleLabel.attributedText = NSAttributedString(string: task.title, attributes: attributes)

        detailLabel.text = task.isCompleted ? "Готово" : task.displayDetail
        glass.alpha = task.isCompleted ? 0.7 : 1
    }

    func configureAnimated(with task: DailyTask, wasCompleted: Bool) {
        if !wasCompleted {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.iconView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            } completion: { _ in
                self.iconView.image = UIImage(systemName: "checkmark.circle.fill")
                self.iconView.tintColor = .systemGreen

                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.iconView.transform = .identity
                }
            }

            UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
                self.glass.alpha = 0.7
                let attrs: [NSAttributedString.Key: Any] = [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                self.titleLabel.attributedText = NSAttributedString(string: task.title, attributes: attrs)
                self.detailLabel.text = "Готово"
            }

            lottieView.play { [weak self] _ in
                self?.lottieView.currentProgress = 0
            }

            if #available(iOS 17.0, *) {
                iconView.addSymbolEffect(.bounce)
            }
        } else {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.iconView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            } completion: { _ in
                self.iconView.image = UIImage(systemName: task.iconName)
                self.iconView.tintColor = .label

                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.iconView.transform = .identity
                }
            }

            UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
                self.glass.alpha = 1
                let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.label]
                self.titleLabel.attributedText = NSAttributedString(string: task.title, attributes: attrs)
                self.detailLabel.text = task.displayDetail
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        lottieView.stop()
        lottieView.currentProgress = 0
        iconView.alpha = 1
        iconView.transform = .identity
        glass.alpha = 1
    }
}
