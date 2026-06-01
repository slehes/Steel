import UIKit
import SnapKit

final class AddHabitViewController: UIViewController {
    private let titleField = UITextField()
    private let iconCollection: UICollectionView
    private let categoryControl = UISegmentedControl(items: [
        HabitCategory.good.title,
        HabitCategory.bad.title
    ])
    private var selectedCategory: HabitCategory
    private var selectedIcon: String

    /// Иконки разделены по типичной семантике: полезные = растения, зарядка, книга;
    /// вредные = сигареты, бокал, крестик. Объединены в один список для удобства,
    /// но фильтруются по выбранной категории.
    private let goodIcons = [
        // Спорт и движение
        "figure.run", "figure.walk", "figure.hiking", "figure.cycling",
        "figure.strengthtraining.traditional", "figure.strengthtraining.functional",
        "figure.core.training", "figure.flexibility", "figure.yoga",
        "figure.mind.and.body", "figure.mixed.cardio", "figure.highintensity.intervaltraining",
        "figure.rowing", "figure.stairs", "figure.arms.raised", "figure.cooldown",
        "figure.cross.training", "figure.play", "dumbbell.fill", "figure.swimming.full",
        // Здоровье
        "drop.fill", "heart.fill", "lungs.fill", "brain.head.profile", "brain.fill",
        "bolt.heart.fill", "heart.circle.fill", "bandage.fill", "pill.fill",
        // Питание
        "leaf.fill", "carrot.fill", "apple.logo", "fork.knife",
        "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        // Сон и режим
        "bed.double.fill", "moon.zzz.fill", "moon.stars.fill", "sun.max.fill",
        "sunrise.fill", "sunset.fill", "clock.fill", "timer",
        // Обучение и продуктивность
        "book.fill", "graduationcap.fill", "pencil", "pencil.line",
        "text.book.closed.fill", "doc.fill", "note.text", "checklist",
        "checkmark.seal.fill", "checkmark.circle.fill",
        // Медитация и ментальность
        "sparkles", "hands.sparkles.fill", "eye.fill", "antenna.radiowaves.left.and.right",
        // Награды
        "trophy.fill", "medal.fill", "star.fill", "flag.fill",
        "seal.fill", "rosette", "crown.fill",
        // Музыка и отдых
        "music.note", "headphones", "figure.socialdance",
    ]

    private let badIcons = [
        // Вредные привычки
        "smoke.fill", "cigarette.fill", "wineglass.fill",
        "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill",
        "cube.fill", "pills.fill",
        // Технологии и соцсети
        "iphone", "iphone.slash", "app.badge.fill",
        "gamecontroller.fill", "tv.fill", "desktopcomputer",
        // Финансы
        "creditcard.fill", "banknote.fill", "cart.fill", "bag.fill",
        // Прокрастинация и лень
        "moon.zzz", "alarm.fill", "zzz", "tired.fill",
        "bed.double.fill", "clock.badge.xmark",
        // Запреты
        "xmark.octagon.fill", "nosign", "minus.circle.fill",
        "hand.raised.slash.fill", "eye.slash.fill",
        "person.badge.minus", "bolt.slash.fill",
        // Негатив
        "flame.fill", "exclamationmark.bubble.fill",
        "exclamationmark.triangle.fill", "hand.point.up.braille",
        "trash.fill", "x.circle.fill",
    ]

    private var icons: [String] {
        selectedCategory == .good ? goodIcons : badIcons
    }

    /// Инициализатор принимает текущую категорию вкладки, чтобы
    /// новая привычка по умолчанию создавалась в активной вкладке.
    init(initialCategory: HabitCategory = .bad) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumLineSpacing = 12
        iconCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)

        self.selectedCategory = initialCategory
        // Дефолтная иконка зависит от категории
        self.selectedIcon = initialCategory == .good
            ? (goodIcons.first ?? "leaf.fill")
            : (badIcons.first ?? "xmark.octagon.fill")

        super.init(nibName: nil, bundle: nil)
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
        titleField.backgroundColor = .clear
        titleField.layer.cornerRadius = 14
        titleField.layer.cornerCurve = .continuous
        titleField.layer.borderWidth = 0.5
        titleField.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        titleField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        titleField.leftViewMode = .always

        // Обёртываем поле ввода в жидкое стекло
        let titleGlass = LiquidGlassView(cornerRadius: 14, intensity: .thin)
        titleGlass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.4)
        titleGlass.contentView.addSubview(titleField)
        titleField.snp.makeConstraints { $0.edges.equalToSuperview() }

        categoryControl.selectedSegmentIndex = selectedCategory == .good ? 0 : 1
        categoryControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)

        // Обёртываем сегментед-контрол в жидкое стекло
        let categoryGlass = LiquidGlassView(cornerRadius: 12, intensity: .thin)
        categoryGlass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.3)
        categoryGlass.contentView.addSubview(categoryControl)
        categoryControl.snp.makeConstraints { $0.edges.equalToSuperview() }

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

        let stack = UIStackView(arrangedSubviews: [titleGlass, categoryLabel, categoryGlass, iconLabel, iconCollection, hint])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(6, after: categoryLabel)
        stack.setCustomSpacing(6, after: iconLabel)
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        titleGlass.snp.makeConstraints { $0.height.equalTo(52) }
        categoryGlass.snp.makeConstraints { $0.height.equalTo(36) }
        iconCollection.snp.makeConstraints { $0.height.equalTo(60) }
    }

    private func applyCategoryStyle() {
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let title = titleField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else {
            titleField.becomeFirstResponder()
            return
        }
        DataManager.shared.addHabit(title: title, iconName: selectedIcon, category: selectedCategory)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        collectionView.reloadData()
    }
}
