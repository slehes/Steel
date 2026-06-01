import UIKit
import SnapKit

final class AddHabitViewController: UIViewController {
    private let titleField = UITextField()
    private let iconCollection: UICollectionView
    private let categoryControl = UISegmentedControl(items: [
        HabitCategory.good.title,
        HabitCategory.bad.title
    ])
    private var selectedCategory: HabitCategory = .bad
    private var selectedIcon: String

    /// Иконки разделены по типичной семантике: полезные = растения, зарядка, книга;
    /// вредные = сигареты, бокал, крестик. Объединены в один список для удобства,
    /// но фильтруются по выбранной категории.
    private let goodIcons = [
        "leaf.fill", "drop.fill", "figure.run", "figure.yoga",
        "figure.strengthtraining.traditional", "figure.flexibility",
        "book.fill", "graduationcap.fill", "pencil", "brain.head.profile",
        "sun.max.fill", "moon.zzz.fill", "bed.double.fill", "apple.logo",
        "carrot.fill", "fork.knife", "cup.and.saucer.fill", "dumbbell.fill",
        "heart.fill", "lungs.fill", "sparkles", "trophy.fill"
    ]

    private let badIcons = [
        "xmark.octagon.fill", "smoke.fill", "cigarette.fill", "wineglass.fill",
        "cube.fill", "hand.raised.slash.fill", "eye.slash.fill", "takeoutbag.and.cup.and.straw.fill",
        "iphone", "gamecontroller.fill", "creditcard.fill", "moon.zzz",
        "alarm.fill", "flame.fill", "exclamationmark.bubble.fill",
        "hand.point.up.braille", "person.badge.minus", "banknote.fill",
        "bed.double.fill", "tired.fill", "birthday.cake.fill", "zzz"
    ]

    private var icons: [String] {
        selectedCategory == .good ? goodIcons : badIcons
    }

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumLineSpacing = 12
        iconCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
        // дефолтная иконка — в зависимости от категории
        self.selectedIcon = badIcons.first ?? "xmark.octagon.fill"
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Новая привычка"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        setup()
        applyCategoryStyle()
    }

    private func setup() {
        titleField.placeholder = "Что внедряем или от чего отказываемся?"
        titleField.font = UIFont.preferredFont(forTextStyle: .body)
        titleField.adjustsFontForContentSizeCategory = true
        titleField.backgroundColor = .secondarySystemGroupedBackground
        titleField.layer.cornerRadius = 14
        titleField.layer.cornerCurve = .continuous
        titleField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        titleField.leftViewMode = .always

        categoryControl.selectedSegmentIndex = selectedCategory == .good ? 0 : 1
        categoryControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)

        iconCollection.backgroundColor = .clear
        iconCollection.showsHorizontalScrollIndicator = false
        iconCollection.delegate = self
        iconCollection.dataSource = self
        iconCollection.register(IconCell.self, forCellWithReuseIdentifier: IconCell.reuseID)

        let iconLabel = UILabel()
        iconLabel.text = "Иконка"
        iconLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        iconLabel.textColor = .secondaryLabel

        let categoryLabel = UILabel()
        categoryLabel.text = "Категория"
        categoryLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        categoryLabel.textColor = .secondaryLabel

        let hint = UILabel()
        hint.text = "Полезная — то, что внедряешь (зарядка, чтение). Вредная — то, от чего отказываешься (курение, сахар)."
        hint.font = UIFont.preferredFont(forTextStyle: .caption2)
        hint.textColor = .tertiaryLabel
        hint.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleField, categoryLabel, categoryControl, iconLabel, iconCollection, hint])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(6, after: categoryLabel)
        stack.setCustomSpacing(6, after: iconLabel)
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        titleField.snp.makeConstraints { $0.height.equalTo(52) }
        categoryControl.snp.makeConstraints { $0.height.equalTo(36) }
        iconCollection.snp.makeConstraints { $0.height.equalTo(60) }
    }

    private func applyCategoryStyle() {
        // Тонируем заголовок сегментед-контрола в цвет категории
        let tint: UIColor = selectedCategory == .good ? .systemGreen : .systemRed
        categoryControl.selectedSegmentTintColor = tint
        categoryControl.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        categoryControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    }

    @objc private func categoryChanged() {
        selectedCategory = categoryControl.selectedSegmentIndex == 0 ? .good : .bad
        selectedIcon = icons.first ?? "xmark.octagon.fill"
        iconCollection.reloadData()
        applyCategoryStyle()
        UIImpactFeedbackGenerator.tap(.light)
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let title = titleField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else {
            titleField.becomeFirstResponder()
            return
        }
        DataManager.shared.addHabit(title: title, iconName: selectedIcon, category: selectedCategory)
        UIImpactFeedbackGenerator.tap(.light)
        dismiss(animated: true)
    }
}

extension AddHabitViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { icons.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: IconCell.reuseID, for: indexPath) as! IconCell
        let icon = icons[indexPath.item]
        cell.configure(icon: icon, selected: icon == selectedIcon)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIcon = icons[indexPath.item]
        UIImpactFeedbackGenerator.tap(.light)
        collectionView.reloadData()
    }
}
