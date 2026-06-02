import UIKit
import SnapKit
import SwiftData

final class TaskDetailViewController: UIViewController {
    private let task: DailyTask
    private let wasCompleted: Bool

    private let containerView = UIView()
    private let glassCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let gifImageView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let amountLabel = UILabel()

    init(task: DailyTask, wasCompleted: Bool) {
        self.task = task
        self.wasCompleted = wasCompleted
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overCurrentContext
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        setup()
        loadGIF()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    private func setup() {
        view.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        glassCard.layer.cornerRadius = 28
        glassCard.layer.cornerCurve = .continuous
        glassCard.clipsToBounds = true
        glassCard.layer.borderWidth = 0.5
        glassCard.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        glassCard.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.7)
        containerView.addSubview(glassCard)
        glassCard.snp.makeConstraints { $0.edges.equalToSuperview() }

        let content = glassCard.contentView

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        content.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(16)
            $0.width.height.equalTo(32)
        }

        gifImageView.contentMode = .scaleAspectFit
        gifImageView.layer.cornerRadius = 20
        gifImageView.clipsToBounds = true
        gifImageView.backgroundColor = .systemGray6
        gifImageView.image = UIImage(systemName: task.iconName)
        gifImageView.tintColor = .systemGray3
        gifImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        content.addSubview(gifImageView)
        gifImageView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(240)
            $0.height.equalTo(160)
        }

        titleLabel.text = task.title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2).withWeight(.bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        content.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(gifImageView.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        detailLabel.text = task.displayDetail
        detailLabel.font = UIFont.systemFont(ofSize: 28, weight: .heavy)
        detailLabel.textColor = .systemGreen
        detailLabel.textAlignment = .center
        content.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.centerX.equalToSuperview()
        }

        // Amount control row (− / value / +)
        let amountBg = UIView()
        amountBg.backgroundColor = .secondarySystemBackground
        amountBg.layer.cornerRadius = 16
        amountBg.layer.cornerCurve = .continuous
        content.addSubview(amountBg)
        amountBg.snp.makeConstraints {
            $0.top.equalTo(detailLabel.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(44)
        }

        minusButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        minusButton.tintColor = .systemRed
        minusButton.addTarget(self, action: #selector(decrementAmount), for: .touchUpInside)
        minusButton.snp.makeConstraints { $0.width.height.equalTo(36) }

        amountLabel.text = "\(task.amount) \(task.unit)"
        amountLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        amountLabel.textColor = .label
        amountLabel.textAlignment = .center
        amountLabel.snp.makeConstraints { $0.width.greaterThanOrEqualTo(80) }

        plusButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        plusButton.tintColor = .systemGreen
        plusButton.addTarget(self, action: #selector(incrementAmount), for: .touchUpInside)
        plusButton.snp.makeConstraints { $0.width.height.equalTo(36) }

        let amountStack = UIStackView(arrangedSubviews: [minusButton, amountLabel, plusButton])
        amountStack.axis = .horizontal
        amountStack.spacing = 16
        amountStack.alignment = .center
        amountBg.addSubview(amountStack)
        amountStack.snp.makeConstraints { $0.center.equalToSuperview() }

        descriptionLabel.text = tipForTask(task.title)
        descriptionLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        content.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(amountBg.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        var doneConfig = UIButton.Configuration.filled()
        doneConfig.title = wasCompleted ? "Отменить" : "Выполнил"
        doneConfig.image = UIImage(systemName: wasCompleted ? "arrow.uturn.backward" : "checkmark.seal.fill")
        doneConfig.imagePadding = 8
        doneConfig.baseBackgroundColor = wasCompleted ? .systemRed : .systemGreen
        doneConfig.baseForegroundColor = .white
        doneConfig.cornerStyle = .large
        doneButton.configuration = doneConfig
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        var skipConfig = UIButton.Configuration.filled()
        skipConfig.title = "Пока нет"
        skipConfig.image = UIImage(systemName: "arrow.clockwise")
        skipConfig.imagePadding = 8
        skipConfig.baseBackgroundColor = .secondarySystemBackground
        skipConfig.baseForegroundColor = .label
        skipConfig.cornerStyle = .large
        skipButton.configuration = skipConfig
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        let buttonsStack = UIStackView(arrangedSubviews: [doneButton, skipButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 12
        buttonsStack.distribution = .fillEqually
        content.addSubview(buttonsStack)
        buttonsStack.snp.makeConstraints {
            $0.top.equalTo(descriptionLabel.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().inset(24)
        }
        doneButton.snp.makeConstraints { $0.height.equalTo(52) }
        skipButton.snp.makeConstraints { $0.height.equalTo(52) }
    }

    private func loadGIF() {
        let taskName = task.title.lowercased()
        let gifName = gifNameForTask(taskName)

        if let path = Bundle.main.path(forResource: gifName, ofType: "gif"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let image = UIImage(data: data) {
            gifImageView.image = image
            gifImageView.contentMode = .scaleAspectFill
            gifImageView.backgroundColor = .clear
        } else {
            let iconName = iconForExercise(taskName)
            gifImageView.image = UIImage(systemName: iconName)
            gifImageView.contentMode = .center
            gifImageView.tintColor = .systemGreen
            gifImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 70, weight: .light)
            gifImageView.backgroundColor = .systemGray6
            animatePlaceholder()
        }
    }

    private func iconForExercise(_ name: String) -> String {
        if name.contains("отжимани") { return "figure.strengthtraining.traditional" }
        if name.contains("приседани") { return "figure.walk" }
        if name.contains("планк") { return "figure.core.training" }
        if name.contains("бег") { return "figure.run" }
        if name.contains("пресс") || name.contains("скручи") { return "figure.core.training" }
        if name.contains("бёрпи") { return "figure.mixed.cardio" }
        if name.contains("подтягив") { return "figure.arms.raised" }
        if name.contains("выпад") { return "figure.arms.raised" }
        if name.contains("жим") { return "dumbbell.fill" }
        if name.contains("станов") { return "dumbbell.fill" }
        if name.contains("скакалк") || name.contains("прыж") { return "figure.play" }
        if name.contains("растяжк") { return "figure.flexibility" }
        return "figure.strengthtraining.traditional"
    }

    private func animatePlaceholder() {
        UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.gifImageView.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        }
    }

    private func gifNameForTask(_ name: String) -> String {
        if name.contains("отжимани") || name.contains("push") { return "pushup" }
        if name.contains("приседани") || name.contains("squat") { return "squat" }
        if name.contains("планк") || name.contains("plank") { return "plank" }
        if name.contains("бег") || name.contains("run") { return "run" }
        if name.contains("пресс") || name.contains("скручи") || name.contains("crunch") { return "crunch" }
        if name.contains("бёрпи") || name.contains("burpee") { return "burpee" }
        if name.contains("выпад") || name.contains("lunge") { return "lunge" }
        if name.contains("подтягив") || name.contains("pull") { return "pullup" }
        if name.contains("жим") || name.contains("bench") { return "bench" }
        if name.contains("скакалк") || name.contains("jump") { return "jumpingjack" }
        if name.contains("растяжк") || name.contains("stretch") { return "stretch" }
        return "exercise"
    }

    private func tipForTask(_ name: String) -> String {
        let tips: [String: String] = [
            "отжимания": "Спина прямая, локти под 45°. Опускайся медленно, поднимайся быстро.",
            "приседания": "Колени по направлению стоп. Спина прямая,尾аза назад как будто садишься на стул.",
            "планка": "Тело прямое, не прогибай поясницу. Живот втянут, ягодицы напряжены.",
            "скручивания": "Нижняя часть спины прижата к полу. Поднимайся за счёт пресса, не шеи.",
            "бёрпи": "Сначала присед → упор лёжа → прыжок вверх. Если сложно — без прыжка.",
            "подтягивания": "Хват чуть шире плеч. Тяни грудью к перекладине, не подбородком.",
            "выпады": "Колено передней ноги не выходит за носок. Заднее колено почти касается пола.",
            "отжимания на брусьях": "Локти строго назад, не разводишь. Опускайся до 90° в локте.",
            "жим лёжа": "Широкий хват, ноги на полу. Опускай штангу к груди, выдох на подъём.",
            "станов тяга": "Спина прямая, ноги на ширине плеч. Тяни за счёт ног, не спины.",
        ]
        for (key, value) in tips {
            if name.contains(key) { return value }
        }
        return "Сосредоточься на правильной технике. Результат важнее скорости."
    }

    private func animateIn() {
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4, options: .curveEaseOut) {
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
    }

    @objc private func incrementAmount() {
        task.amount += 1
        updateAmountUI()
    }

    @objc private func decrementAmount() {
        guard task.amount > 1 else { return }
        task.amount -= 1
        updateAmountUI()
    }

    private func updateAmountUI() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        detailLabel.text = task.displayDetail
        amountLabel.text = "\(task.amount) \(task.unit)"
        try? DataManager.shared.context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
    }

    @objc private func closeTapped() {
        dismissWithAnimation()
    }

    @objc private func doneTapped() {
        if !task.isCompleted {
            DataManager.shared.toggleTask(task)
        } else {
            DataManager.shared.toggleTask(task)
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        dismissWithAnimation()
    }

    @objc private func skipTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismissWithAnimation()
    }

    private func dismissWithAnimation() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.containerView.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }
}