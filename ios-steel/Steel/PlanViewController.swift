import UIKit
import SnapKit
import Hero
import SwiftData

final class PlanViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let backgroundView = PersonalBackgroundView()
    private let headerLabel = UILabel()
    private let bodyLabel = UILabel()
    private let regenerateButton = UIButton(type: .system)
    private let entriesStack = UIStackView()
    private let emptyView = UILabel()

    private var plan: TrainingPlan?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Мой план"
        setupBackground()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
        setup()
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

    private func setup() {
        view.hero.isEnabled = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true

        // Header
        headerLabel.font = UIFont.preferredFont(forTextStyle: .title2).withWeight(.bold)
        headerLabel.textColor = .label
        headerLabel.numberOfLines = 0

        // Body description
        bodyLabel.numberOfLines = 0
        bodyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.lineBreakMode = .byWordWrapping

        // Regen button with glass
        let regenGlass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        regenGlass.layer.cornerRadius = 16
        regenGlass.layer.cornerCurve = .continuous
        regenGlass.clipsToBounds = true
        regenGlass.layer.borderWidth = 0.5
        regenGlass.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        regenGlass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)

        var regenConfig = UIButton.Configuration.filled()
        regenConfig.title = "Пересоздать план"
        regenConfig.image = UIImage(systemName: "arrow.clockwise")
        regenConfig.imagePadding = 8
        regenConfig.baseBackgroundColor = .label
        regenConfig.baseForegroundColor = .systemBackground
        regenConfig.cornerStyle = .large
        regenerateButton.configuration = regenConfig
        regenerateButton.addTarget(self, action: #selector(regeneratePlan), for: .touchUpInside)
        regenGlass.contentView.addSubview(regenerateButton)
        regenerateButton.snp.makeConstraints { $0.edges.equalToSuperview().inset(14) }

        // Entries stack
        entriesStack.axis = .vertical
        entriesStack.spacing = 10

        let content = UIView()
        scrollView.addSubview(content)
        content.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(30)
            $0.width.equalTo(view).offset(-40)
        }

        content.addSubview(headerLabel)
        content.addSubview(bodyLabel)
        content.addSubview(regenGlass)
        content.addSubview(entriesStack)

        headerLabel.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview() }
        bodyLabel.snp.makeConstraints {
            $0.top.equalTo(headerLabel.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
        }
        regenGlass.snp.makeConstraints {
            $0.top.equalTo(bodyLabel.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(52)
        }
        entriesStack.snp.makeConstraints {
            $0.top.equalTo(regenGlass.snp.bottom).offset(24)
            $0.leading.trailing.bottom.equalToSuperview()
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

        if let plan = plan, !plan.body.isEmpty {
            scrollView.isHidden = false
            emptyView.isHidden = true
            headerLabel.text = plan.title.isEmpty ? "Программа тренировок" : plan.title
            bodyLabel.text = plan.body
            loadEntries()
        } else {
            scrollView.isHidden = true
            emptyView.isHidden = false
        }
    }

    private func loadEntries() {
        entriesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let entries = fetchEntries()
        if entries.isEmpty { return }

        let sectionLabel = UILabel()
        sectionLabel.text = "Задания плана"
        sectionLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        sectionLabel.textColor = .secondaryLabel
        entriesStack.addArrangedSubview(sectionLabel)

        for entry in entries {
            let card = makeEntryCard(entry)
            entriesStack.addArrangedSubview(card)
        }
    }

    private func fetchEntries() -> [PlanEntry] {
        let descriptor = FetchDescriptor<PlanEntry>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? DataManager.shared.context.fetch(descriptor)) ?? []
    }

    private func makeEntryCard(_ entry: PlanEntry) -> UIView {
        let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        glass.layer.cornerRadius = 16
        glass.layer.cornerCurve = .continuous
        glass.clipsToBounds = true
        glass.layer.borderWidth = 0.5
        glass.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor

        let icon = UIImageView(image: UIImage(systemName: entry.iconName))
        icon.tintColor = entry.isCompleted ? .systemGreen : .label
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)

        let label = UILabel()
        label.text = entry.title
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.numberOfLines = 2
        label.textColor = entry.isCompleted ? .secondaryLabel : .label

        let checkmark = UIImageView(image: UIImage(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle"))
        checkmark.tintColor = entry.isCompleted ? .systemGreen : .systemGray3
        checkmark.contentMode = .scaleAspectFit

        glass.contentView.addSubview(icon)
        glass.contentView.addSubview(label)
        glass.contentView.addSubview(checkmark)

        icon.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(30)
        }
        label.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(12)
            $0.trailing.equalTo(checkmark.snp.leading).offset(-12)
            $0.centerY.equalToSuperview()
        }
        checkmark.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(26)
        }

        glass.snp.makeConstraints { $0.height.equalTo(64) }

        // Long press to delete
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(entryLongPressed(_:)))
        glass.addGestureRecognizer(longPress)

        // Tap to toggle
        let tap = UITapGestureRecognizer(target: self, action: #selector(entryTapped(_:)))
        glass.addGestureRecognizer(tap)

        glass.tag = entry.hashValue

        return glass
    }

    @objc private func entryTapped(_ gesture: UIGestureRecognizer) {
        let entries = fetchEntries()
        guard let view = gesture.view else { return }

        // Find entry by tag
        for (index, entry) in entries.enumerated() {
            if entry.hashValue == view.tag {
                entry.isCompleted.toggle()
                try? DataManager.shared.context.save()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                animateEntryToggle(view: view, completed: entry.isCompleted, index: index)
                break
            }
        }
    }

    private func animateEntryToggle(view: UIView, completed: Bool, index: Int) {
        let icon = view.subviews.first(where: { $0 is UIImageView }) as? UIImageView
        let label = view.subviews.dropFirst().first(where: { $0 is UILabel }) as? UILabel

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4, options: .curveEaseOut) {
            view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            icon?.image = UIImage(systemName: completed ? "checkmark.circle.fill" : "circle")
            icon?.tintColor = completed ? .systemGreen : .systemGray3
            label?.textColor = completed ? .secondaryLabel : .label
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                view.transform = .identity
            }
        }
    }

    @objc private func entryLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let view = gesture.view else { return }

        let entries = fetchEntries()
        for entry in entries {
            if entry.hashValue == view.tag {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

                // Show delete confirmation with glass effect
                showDeleteConfirmation(entry: entry, in: view)
                break
            }
        }
    }

    private func showDeleteConfirmation(entry: PlanEntry, in view: UIView) {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlay.layer.cornerRadius = 16
        overlay.alpha = 0
        view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }

        let glass2 = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        glass2.layer.cornerRadius = 16
        glass2.layer.cornerCurve = .continuous
        glass2.clipsToBounds = true

        var deleteConfig = UIButton.Configuration.filled()
        deleteConfig.title = "Удалить"
        deleteConfig.image = UIImage(systemName: "trash.fill")
        deleteConfig.imagePadding = 8
        deleteConfig.baseBackgroundColor = .systemRed
        deleteConfig.baseForegroundColor = .white
        deleteConfig.cornerStyle = .large

        var cancelConfig = UIButton.Configuration.filled()
        cancelConfig.title = "Отмена"
        cancelConfig.image = UIImage(systemName: "xmark")
        cancelConfig.imagePadding = 8
        cancelConfig.baseBackgroundColor = .secondarySystemBackground
        cancelConfig.baseForegroundColor = .label
        cancelConfig.cornerStyle = .large

        let deleteBtn = UIButton(configuration: deleteConfig)
        let cancelBtn = UIButton(configuration: cancelConfig)

        let stack = UIStackView(arrangedSubviews: [deleteBtn, cancelBtn])
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fillEqually

        glass2.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(14) }
        deleteBtn.snp.makeConstraints { $0.height.equalTo(44) }
        cancelBtn.snp.makeConstraints { $0.height.equalTo(44) }

        view.addSubview(glass2)
        glass2.snp.makeConstraints { $0.edges.equalToSuperview() }

        deleteBtn.addAction(UIAction { [weak self] _ in
            DataManager.shared.context.delete(entry)
            try? DataManager.shared.context.save()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self?.render()
        }, for: .touchUpInside)

        cancelBtn.addAction(UIAction { [weak self] _ in
            self?.dismissDeleteConfirmation(glass: glass2, overlay: overlay)
        }, for: .touchUpInside)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: .curveEaseOut) {
            overlay.alpha = 1
            glass2.alpha = 1
        }
    }

    private func dismissDeleteConfirmation(glass: UIView, overlay: UIView) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            glass.alpha = 0
            overlay.alpha = 0
        } completion: { _ in
            glass.removeFromSuperview()
            overlay.removeFromSuperview()
        }
    }

    @objc private func regeneratePlan() {
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

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}