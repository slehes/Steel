import UIKit
import SnapKit

/// Заголовок секции в привычках: «Полезные» / «Вредные».
/// Стеклянная плашка с иконкой и счётчиком привычек в секции.
final class HabitSectionHeader: UICollectionReusableView {
    static let reuseID = "HabitSectionHeader"

    private let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        glass.layer.cornerRadius = 18
        glass.layer.cornerCurve = .continuous
        glass.clipsToBounds = true
        glass.layer.borderWidth = 0.5
        glass.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        addSubview(glass)
        glass.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(6)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        glass.contentView.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(14)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(24)
        }

        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        glass.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(10)
            $0.centerY.equalToSuperview()
        }

        countLabel.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        countLabel.textColor = .secondaryLabel
        glass.contentView.addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(14)
            $0.centerY.equalToSuperview()
        }
    }

    func configure(title: String, icon: String, count: Int) {
        titleLabel.text = title
        iconView.image = UIImage(systemName: icon)
        let word = titleWordForm(count)
        countLabel.text = "\(count) \(word)"
    }

    private func titleWordForm(_ n: Int) -> String {
        // очень простая плюрализация для русского
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "штук" }
        if mod10 == 1 { return "штука" }
        if mod10 >= 2 && mod10 <= 4 { return "штуки" }
        return "штук"
    }
}
