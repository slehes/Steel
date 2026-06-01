import UIKit
import SnapKit

final class AddTaskViewController: UIViewController {
    private let titleField = UITextField()
    private let amountField = UITextField()
    private let unitField = UITextField()
    private let iconCollection: UICollectionView
    private var selectedIcon = "figure.run"

    private let icons = [
        "figure.run", "figure.strengthtraining.traditional", "figure.core.training",
        "figure.cross.training", "figure.mind.and.body", "figure.play", "drop.fill",
        "dumbbell.fill", "bolt.heart.fill", "flame.fill", "book.fill", "pencil",
        "brain.head.profile", "bed.double.fill", "leaf.fill", "sun.max.fill",
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
        view.backgroundColor = .systemBackground
        title = "Новое задание"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        setup()
    }

    private func setup() {
        styleField(titleField, placeholder: "Название")
        styleField(amountField, placeholder: "Количество")
        amountField.keyboardType = .numberPad
        styleField(unitField, placeholder: "Ед. (раз, мин, л)")

        let amountRow = UIStackView(arrangedSubviews: [amountField, unitField])
        amountRow.spacing = 12
        amountRow.distribution = .fillEqually

        iconCollection.backgroundColor = .clear
        iconCollection.showsHorizontalScrollIndicator = false
        iconCollection.delegate = self
        iconCollection.dataSource = self
        iconCollection.register(IconCell.self, forCellWithReuseIdentifier: IconCell.reuseID)

        let iconLabel = sectionLabel("Иконка")

        let stack = UIStackView(arrangedSubviews: [titleField, amountRow, iconLabel, iconCollection])
        stack.axis = .vertical
        stack.spacing = 18
        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        titleField.snp.makeConstraints { $0.height.equalTo(52) }
        amountField.snp.makeConstraints { $0.height.equalTo(52) }
        iconCollection.snp.makeConstraints { $0.height.equalTo(60) }
    }

    private func styleField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.backgroundColor = .secondarySystemBackground
        field.layer.cornerRadius = 14
        field.layer.cornerCurve = .continuous
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        return label
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let title = titleField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else {
            titleField.becomeFirstResponder()
            return
        }
        let amount = Int(amountField.text ?? "") ?? 1
        let unit = unitField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        DataManager.shared.addTask(title: title, amount: amount, unit: unit, iconName: selectedIcon)
        UIImpactFeedbackGenerator.tap(.light)
        dismiss(animated: true)
    }
}

extension AddTaskViewController: UICollectionViewDataSource, UICollectionViewDelegate {
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

final class IconCell: UICollectionViewCell {
    static let reuseID = "IconCell"
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .center
        imageView.tintColor = .label
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, selected: Bool) {
        imageView.image = UIImage(systemName: icon)
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        contentView.backgroundColor = selected ? .label : .secondarySystemBackground
        imageView.tintColor = selected ? .systemBackground : .label
    }
}
