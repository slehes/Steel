import UIKit
import SnapKit
import SPIndicator

final class GoalsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let backgroundView = PersonalBackgroundView()
    private let goalsStack = UIStackView()
    private let emptyLabel = UILabel()
    private let addButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Цели на год"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        setup()
        render()
        NotificationCenter.default.addObserver(self, selector: #selector(render), name: .steelSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
    }

    private func setup() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true

        goalsStack.axis = .vertical
        goalsStack.spacing = 12
        scrollView.addSubview(goalsStack)
        goalsStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(80)
        }

        emptyLabel.text = "Целей пока нет.\nНажми +, чтобы поставить цель до конца года."
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        emptyLabel.textColor = .secondaryLabel
        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(40)
        }

        var addConfig = UIButton.Configuration.filled()
        addConfig.title = "Добавить цель"
        addConfig.image = UIImage(systemName: "plus")
        addConfig.imagePadding = 8
        addConfig.baseBackgroundColor = .systemGreen
        addConfig.baseForegroundColor = .white
        addConfig.cornerStyle = .large
        addButton.configuration = addConfig
        addButton.addTarget(self, action: #selector(addGoal), for: .touchUpInside)
        addButton.backgroundColor = .systemGreen
        addButton.layer.cornerRadius = 20
        addButton.layer.cornerCurve = .continuous
        view.addSubview(addButton)
        addButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
            $0.height.equalTo(52)
        }
    }

    @objc private func render() {
        let goals = DataManager.shared.settings.yearGoals

        goalsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if goals.isEmpty {
            scrollView.isHidden = true
            emptyLabel.isHidden = false
            addButton.isHidden = false
        } else {
            scrollView.isHidden = false
            emptyLabel.isHidden = true

            let header = UILabel()
            header.text = "До 31 декабря 2026"
            header.font = UIFont.preferredFont(forTextStyle: .headline)
            header.textColor = .secondaryLabel
            goalsStack.addArrangedSubview(header)

            for (index, goal) in goals.enumerated() {
                let card = makeGoalCard(goal, index: index)
                goalsStack.addArrangedSubview(card)
            }
        }
    }

    private func makeGoalCard(_ goal: YearGoal, index: Int) -> UIView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor

        let iconView = UIImageView(image: UIImage(systemName: goal.iconName))
        iconView.tintColor = .systemGreen
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)

        let titleLabel = UILabel()
        titleLabel.text = goal.title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2

        let valueLabel = UILabel()
        valueLabel.text = "\(goal.currentValue) / \(goal.targetValue)"
        valueLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = .secondaryLabel

        let track = UIView()
        track.backgroundColor = .systemGray5
        track.layer.cornerRadius = 4
        track.clipsToBounds = true

        let fill = UIView()
        fill.backgroundColor = .systemGreen
        fill.layer.cornerRadius = 4
        fill.tag = 888
        track.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            fill.snp.makeConstraints { $0.width.equalTo(track.bounds.width * goal.progress).constraint }
        }

        let minusBtn = UIButton(type: .system)
        minusBtn.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        minusBtn.tintColor = .secondaryLabel
        minusBtn.addAction(UIAction { [weak self] _ in
            self?.updateGoal(index: index, current: max(0, goal.currentValue - 1))
        }, for: .touchUpInside)

        let plusBtn = UIButton(type: .system)
        plusBtn.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        plusBtn.tintColor = .systemGreen
        plusBtn.addAction(UIAction { [weak self] _ in
            self?.updateGoal(index: index, current: min(goal.targetValue, goal.currentValue + 1))
        }, for: .touchUpInside)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteBtn.tintColor = .systemRed
        deleteBtn.addAction(UIAction { [weak self] _ in
            self?.deleteGoal(index: index)
        }, for: .touchUpInside)

        let controls = UIStackView(arrangedSubviews: [minusBtn, plusBtn])
        controls.spacing = 16

        let content = card.contentView
        content.addSubview(iconView)
        content.addSubview(titleLabel)
        content.addSubview(valueLabel)
        content.addSubview(track)
        content.addSubview(controls)
        content.addSubview(deleteBtn)

        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(16)
            $0.top.equalToSuperview().inset(16)
            $0.width.height.equalTo(30)
        }
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(12)
            $0.top.equalToSuperview().inset(16)
            $0.trailing.equalTo(deleteBtn.snp.leading).offset(-8)
        }
        valueLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        track.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(valueLabel.snp.bottom).offset(10)
            $0.height.equalTo(8)
            $0.bottom.equalToSuperview().inset(16)
        }

        controls.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(16)
            $0.centerY.equalTo(iconView)
        }
        deleteBtn.snp.makeConstraints {
            $0.trailing.equalTo(controls.snp.leading).offset(-12)
            $0.centerY.equalTo(iconView)
            $0.width.height.equalTo(24)
        }

        DispatchQueue.main.async {
            fill.snp.remakeConstraints {
                $0.leading.top.bottom.equalToSuperview()
                $0.width.equalToSuperview().multipliedBy(goal.progress)
            }
            UIView.animate(withDuration: 1.5, delay: 0, options: .curveEaseOut) {
                card.layoutIfNeeded()
            }
        }

        return card
    }

    private func updateGoal(index: Int, current: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DataManager.shared.updateSettings { settings in
            settings.yearGoals[index].currentValue = current
        }
        render()

        let goal = DataManager.shared.settings.yearGoals[index]
        if current > 0 {
            DataManager.shared.addMessage(
                "Моя цель: \(goal.title) — до конца года \(goal.targetValue). Уже сделано: \(current) из \(goal.targetValue).",
                isUser: true
            )
        }
    }

    private func deleteGoal(index: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DataManager.shared.updateSettings { settings in
            settings.yearGoals.remove(at: index)
        }
        render()
    }

    @objc private func addGoal() {
        let alert = UIAlertController(title: "Новая цель", message: "Что хочешь достичь до конца года?", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Например: 10 подтягиваний"
        }
        alert.addTextField { tf in
            tf.placeholder = "Целевое значение (например: 10)"
            tf.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak self] _ in
            guard let goalTitle = alert.textFields?[0].text, !goalTitle.isEmpty,
                  let valueStr = alert.textFields?[1].text,
                  let goalValue = Int(valueStr), goalValue > 0 else {
                return
            }
            let icon = self?.suggestedIcon(for: goalTitle) ?? "target"
            let goal = YearGoal(title: goalTitle, targetValue: goalValue, iconName: icon)
            DataManager.shared.updateSettings { settings in
                settings.yearGoals.append(goal)
            }
            self?.render()
            DataManager.shared.addMessage(
                "Моя цель на год: \(goalTitle) — достичь \(goalValue) до 31 декабря 2026.",
                isUser: true
            )
            SPIndicator.present(title: "Цель добавлена!", preset: .done, haptic: .success)
        }))
        present(alert, animated: true)
    }

    private func suggestedIcon(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("подтягив") || lower.contains("pull") { return "figure.arms.raised" }
        if lower.contains("отжимани") || lower.contains("push") { return "figure.strengthtraining.traditional" }
        if lower.contains("приседани") || lower.contains("squat") { return "figure.walk" }
        if lower.contains("бег") || lower.contains("run") { return "figure.run" }
        if lower.contains("пресс") || lower.contains("abs") { return "figure.core.training" }
        if lower.contains("вес") || lower.contains("weight") { return "scalemass.fill" }
        if lower.contains("планк") { return "figure.core.training" }
        return "trophy.fill"
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }
}