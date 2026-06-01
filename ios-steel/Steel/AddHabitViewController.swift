import UIKit
import SnapKit

final class AddHabitViewController: UIViewController {
    private let titleField = UITextField()
    private let iconCollection: UICollectionView
    private var selectedIcon = "xmark.octagon"

    private let icons = [
        // Habits & Lifestyle
        "xmark.octagon.fill", "cube.fill", "leaf.fill", "drop.fill",
        "flame.fill", "moon.zzz.fill", "sun.max.fill", "cloud.moon.fill",
        // Body
        "figure.arms.raised", "figure.cooldown", "figure.mixed.cardio",
        "heart.fill", "lungs.fill", "brain.head.profile", "figure.brain",
        // Discipline
        "alarm.fill", "clock.fill", "timer", "stopwatch.fill",
        "flag.fill", "target", "scope", "trophy.fill", "medal.fill",
        // Tech & Productivity
        "desktopcomputer", "laptopcomputer", "iphone", "ipad",
        "gamecontroller.fill", "book.fill", "pencil", "graduationcap.fill",
        // Food & Restriction
        "takeoutbag.and.cup.and.straw.fill", "cup.and.saucer.fill", "wineglass.fill",
        "carrot.fill", "apple.logo", "fork.knife", "birthday.cake.fill",
        // Bad habits
        "smoke.fill", "cigarette.fill", "exclamationmark.bubble.fill",
        "hand.raised.slash.fill", "eye.slash.fill", "hand.point.up.braille",
        // Mind
        "sparkles", "brain.fill", "moon.stars.fill", "sunrise.fill",
        // Social
        "person.2.fill", "person.badge.minus", "person.crop.circle.badge.checkmark",
        "creditcard.fill", "dollarsign.circle.fill", "banknote.fill",
        // Sleep
        "bed.double.fill", "moon.zzz", "tired.fill", "zzz",
    ]

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumLineSpacing = 12
        iconCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Use systemGroupedBackground for a fully dark/gray background
        view.backgroundColor = .systemGroupedBackground
        title = "Новая привычка"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        setup()
    }

    private func setup() {
        titleField.placeholder = "Что бросаем?"
        titleField.font = UIFont.preferredFont(forTextStyle: .body)
        titleField.adjustsFontForContentSizeCategory = true
        titleField.backgroundColor = .secondarySystemGroupedBackground
        titleField.layer.cornerRadius = 14
        titleField.layer.cornerCurve = .continuous
        titleField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        titleField.leftViewMode = .always

        iconCollection.backgroundColor = .clear
        iconCollection.showsHorizontalScrollIndicator = false
        iconCollection.delegate = self
        iconCollection.dataSource = self
        iconCollection.register(IconCell.self, forCellWithReuseIdentifier: IconCell.reuseID)

        let iconLabel = UILabel()
        iconLabel.text = "Иконка"
        iconLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        iconLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [titleField, iconLabel, iconCollection])
        stack.axis = .vertical
        stack.spacing = 18
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        titleField.snp.makeConstraints { $0.height.equalTo(52) }
        iconCollection.snp.makeConstraints { $0.height.equalTo(60) }
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let title = titleField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else {
            titleField.becomeFirstResponder()
            return
        }
        DataManager.shared.addHabit(title: title, iconName: selectedIcon)
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
