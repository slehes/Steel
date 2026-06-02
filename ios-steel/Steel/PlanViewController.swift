import UIKit
import SnapKit
import Hero
import SwiftData
import SPIndicator

final class PlanViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let backgroundView = PersonalBackgroundView()
    private let contentStack = UIStackView()
    private let emptyView = UILabel()

    private var plan: TrainingPlan?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Мой план"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
        setupBackground()
        setupUI()
        render()
        NotificationCenter.default.addObserver(self, selector: #selector(render), name: .steelTasksChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        render()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
    }

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear

        contentStack.axis = .vertical
        contentStack.spacing = 14
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(30)
            $0.width.equalTo(view).offset(-40)
        }

        emptyView.text = "Плана пока нет.\nПопроси ИИ Тренера составить программу."
        emptyView.numberOfLines = 0
        emptyView.textAlignment = .center
        emptyView.font = UIFont.preferredFont(forTextStyle: .body)
        emptyView.textColor = .secondaryLabel
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(40)
        }
    }

    @objc private func render() {
        plan = DataManager.shared.currentPlan()

        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let plan = plan, !plan.title.isEmpty || !plan.body.isEmpty {
            scrollView.isHidden = false
            emptyView.isHidden = true

            let card = makePlanCard(plan)
            contentStack.addArrangedSubview(card)

            let entries = fetchEntries()
            if !entries.isEmpty {
                let sectionLabel = UILabel()
                sectionLabel.text = "ЗАДАНИЯ ПЛАНА"
                sectionLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
                sectionLabel.textColor = .secondaryLabel
                contentStack.addArrangedSubview(sectionLabel)

                for entry in entries {
                    let entryRow = makeEntryRow(entry)
                    contentStack.addArrangedSubview(entryRow)
                }
            }
        } else {
            scrollView.isHidden = true
            emptyView.isHidden = false
        }
    }

    private func makePlanCard(_ plan: TrainingPlan) -> UIView {
        let glass = LiquidGlassView(cornerRadius: 24, intensity: .regular)
        glass.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.45)

        let icon = UIImageView(image: UIImage(systemName: "flame.fill"))
        icon.tintColor = .systemGreen
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        icon.snp.makeConstraints { $0.width.height.equalTo(36) }

        let title = UILabel()
        title.text = plan.title.isEmpty ? "Программа тренировок" : plan.title
        title.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        title.textColor = .label
        title.numberOfLines = 0

        let meta = UILabel()
        let parsed = PlanParser.parse(plan.body)
        let parts: [String] = [
            parsed.program.duration.isEmpty ? nil : "\(parsed.program.duration)",
            parsed.program.level.isEmpty ? nil : "\(parsed.program.level)",
            "Обновлено: \(dateString(plan.updatedAt))"
        ].compactMap { $0 }
        meta.text = parts.joined(separator: "  •  ")
        meta.font = UIFont.preferredFont(forTextStyle: .caption1)
        meta.textColor = .secondaryLabel
        meta.numberOfLines = 0

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        chevron.tintColor = .tertiaryLabel

        let textStack = UIStackView(arrangedSubviews: [title, meta])
        textStack.axis = .vertical
        textStack.spacing = 6

        let h = UIStackView(arrangedSubviews: [icon, textStack, UIView(), chevron])
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 14

        glass.contentView.addSubview(h)
        h.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(openDetail))
        glass.addGestureRecognizer(tap)
        glass.isUserInteractionEnabled = true

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnPlan))
        longPress.minimumPressDuration = 0.5
        glass.addGestureRecognizer(longPress)

        return glass
    }

    private func makeEntryRow(_ entry: PlanEntry) -> UIView {
        let row = UIView()
        row.layer.cornerRadius = 14
        row.layer.cornerCurve = .continuous
        row.layer.borderWidth = 0.5
        row.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        row.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.3)

        let icon = UIImageView(image: UIImage(systemName: entry.iconName))
        icon.tintColor = entry.isCompleted ? .systemGreen : .label
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        let label = UILabel()
        label.text = entry.title
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 2
        label.textColor = entry.isCompleted ? .secondaryLabel : .label

        let checkmark = UIImageView(image: UIImage(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle"))
        checkmark.tintColor = entry.isCompleted ? .systemGreen : .systemGray3
        checkmark.contentMode = .scaleAspectFit
        checkmark.snp.makeConstraints { $0.width.height.equalTo(22) }

        let h = UIStackView(arrangedSubviews: [icon, label, checkmark])
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 10
        row.addSubview(h)
        h.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
        row.snp.makeConstraints { $0.height.greaterThanOrEqualTo(48) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(entryTapped(_:)))
        row.addGestureRecognizer(tap)
        row.tag = entry.hashValue

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(entryLongPressed(_:)))
        row.addGestureRecognizer(longPress)

        return row
    }

    private func fetchEntries() -> [PlanEntry] {
        let descriptor = FetchDescriptor<PlanEntry>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? DataManager.shared.context.fetch(descriptor)) ?? []
    }

    @objc private func entryTapped(_ gesture: UIGestureRecognizer) {
        let entries = fetchEntries()
        guard let view = gesture.view else { return }
        for entry in entries {
            if entry.hashValue == view.tag {
                entry.isCompleted.toggle()
                try? DataManager.shared.context.save()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                render()
                break
            }
        }
    }

    @objc private func entryLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let view = gesture.view else { return }
        let entries = fetchEntries()
        for entry in entries {
            if entry.hashValue == view.tag {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                let alert = UIAlertController(title: entry.title, message: nil, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
                    DataManager.shared.context.delete(entry)
                    try? DataManager.shared.context.save()
                    self?.render()
                })
                alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
                present(alert, animated: true)
                break
            }
        }
    }

    @objc private func openDetail() {
        guard let plan else {
            SPIndicator.present(title: "Плана пока нет", message: "Попроси ИИ составить программу", preset: .error)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let detail = PlanDetailViewController(plan: plan)
        let nav = UINavigationController(rootViewController: detail)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large(), .medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    @objc private func handleLongPressOnPlan(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, plan != nil else { return }

        let alert = UIAlertController(title: "План тренировок", message: nil, preferredStyle: .actionSheet)

        let regenerate = UIAlertAction(title: "Пересоздать", style: .default) { [weak self] _ in
            self?.regeneratePlan()
        }
        regenerate.setValue(UIImage(systemName: "arrow.clockwise"), forKey: "image")

        let delete = UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.deletePlan()
        }
        delete.setValue(UIImage(systemName: "trash"), forKey: "image")

        alert.addAction(regenerate)
        alert.addAction(delete)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func regeneratePlan() {
        dismiss(animated: true) { [weak self] in
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first?.rootViewController else { return }
            let chat = AIChatViewController()
            let nav = UINavigationController(rootViewController: chat)
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 28
            }
            rootVC.present(nav, animated: true)
        }
    }

    private func deletePlan() {
        guard let plan = plan else { return }
        DataManager.shared.context.delete(plan)
        try? DataManager.shared.context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SPIndicator.present(title: "План удалён", preset: .done, haptic: .success)
        render()
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }
}
