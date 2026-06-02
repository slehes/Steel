import UIKit
import SnapKit
import SPIndicator

final class EditNameIconViewController: UIViewController {

    private let currentName: String
    private let currentIcon: String
    private let onSave: (String, String) -> Void

    private let nameField = UITextField()
    private var selectedIcon: String
    private var iconButtons: [UIButton] = []

    private static let icons: [String] = [
        "figure.strengthtraining.traditional", "figure.core.training", "figure.run",
        "figure.walk", "figure.flexibility", "figure.mixed.cardio", "figure.arms.raised",
        "figure.play", "dumbbell.fill", "bolt.fill", "flame.fill", "heart.fill",
        "drop.fill", "moon.fill", "sun.max.fill", "leaf.fill", "book.fill",
        "pencil", "checkmark.circle.fill", "star.fill", "trophy.fill", "medal.fill",
        "bicycle", "skateboard", "soccerball", "basketball.fill", "tennis.racket",
        "music.note", "brain.head.profile", "eye.fill", "hand.raised.fill",
        "cup.and.saucer.fill", "fork.knife", "bed.double.fill", "clock.fill",
        "iphone.slash", "wifi.slash", "bag.badge.minus", "snowflake",
    ]

    init(name: String, icon: String, onSave: @escaping (String, String) -> Void) {
        self.currentName = name
        self.currentIcon = icon
        self.selectedIcon = icon
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        scroll.snp.makeConstraints { $0.edges.equalToSuperview() }

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 24
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 40, right: 20)
        scroll.addSubview(container)
        container.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(view)
        }

        // Title
        let titleLbl = UILabel()
        titleLbl.text = "Редактировать"
        titleLbl.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLbl.textColor = .label
        container.addArrangedSubview(titleLbl)

        // Name field
        let fieldCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        fieldCard.layer.cornerRadius = 14
        fieldCard.layer.cornerCurve = .continuous
        fieldCard.clipsToBounds = true
        fieldCard.snp.makeConstraints { $0.height.equalTo(52) }

        nameField.text = currentName
        nameField.font = UIFont.systemFont(ofSize: 17)
        nameField.textColor = .label
        nameField.clearButtonMode = .whileEditing
        nameField.returnKeyType = .done
        nameField.delegate = self
        fieldCard.contentView.addSubview(nameField)
        nameField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
        }
        container.addArrangedSubview(fieldCard)

        // Icons label
        let iconsLbl = UILabel()
        iconsLbl.text = "Иконка"
        iconsLbl.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        iconsLbl.textColor = .label
        container.addArrangedSubview(iconsLbl)

        // Icons grid
        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 8
        container.addArrangedSubview(gridStack)

        let iconsPerRow = 7
        var row: UIStackView?
        for (idx, icon) in Self.icons.enumerated() {
            if idx % iconsPerRow == 0 {
                row = UIStackView()
                row!.axis = .horizontal
                row!.spacing = 8
                row!.distribution = .fillEqually
                gridStack.addArrangedSubview(row!)
            }
            let btn = makeIconButton(icon)
            row?.addArrangedSubview(btn)
            iconButtons.append(btn)
        }
        // Fill last row with empty views if needed
        if let lastRow = row {
            let remaining = Self.icons.count % iconsPerRow
            if remaining != 0 {
                for _ in remaining..<iconsPerRow {
                    lastRow.addArrangedSubview(UIView())
                }
            }
        }

        refreshIconSelection()

        // Save button
        let saveBtn = UIButton(type: .system)
        saveBtn.setTitle("Сохранить", for: .normal)
        saveBtn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        saveBtn.backgroundColor = .systemBlue
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.layer.cornerRadius = 14
        saveBtn.layer.cornerCurve = .continuous
        saveBtn.addTarget(self, action: #selector(save), for: .touchUpInside)
        saveBtn.snp.makeConstraints { $0.height.equalTo(52) }
        container.addArrangedSubview(saveBtn)
    }

    private func makeIconButton(_ icon: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: icon,
                             withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.layer.cornerRadius = 10
        btn.layer.cornerCurve = .continuous
        btn.backgroundColor = UIColor.secondarySystemBackground
        btn.snp.makeConstraints { $0.height.equalTo(44) }
        btn.accessibilityLabel = icon
        btn.addTarget(self, action: #selector(iconTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func refreshIconSelection() {
        for btn in iconButtons {
            let icon = btn.accessibilityLabel ?? ""
            let isSelected = icon == selectedIcon
            btn.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.15) : UIColor.secondarySystemBackground
            btn.tintColor = isSelected ? .systemBlue : .secondaryLabel
            btn.layer.borderWidth = isSelected ? 2 : 0
            btn.layer.borderColor = UIColor.systemBlue.cgColor
        }
    }

    @objc private func iconTapped(_ sender: UIButton) {
        guard let icon = sender.accessibilityLabel else { return }
        selectedIcon = icon
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshIconSelection()
    }

    @objc private func save() {
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else {
            SPIndicator.present(title: "Введите название", preset: .error, haptic: .error)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSave(name, selectedIcon)
        dismiss(animated: true)
    }
}

extension EditNameIconViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
