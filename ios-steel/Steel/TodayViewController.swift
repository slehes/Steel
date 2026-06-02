import UIKit
import SnapKit
import SPIndicator
import Hero

final class TodayViewController: UIViewController {
    private var tasks: [DailyTask] = []

    private let backgroundView = PersonalBackgroundView()
    private var collectionView: UICollectionView!
    private let actionBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let finishButton = UIButton(type: .system)
    private var actionBarHidden = false
    private let motivationLabel = UILabel()

    private var extraButtonsHidden = false
    private var goalsButton: UIBarButtonItem!
    private var bgButton: UIBarButtonItem!
    private var hideButton: UIBarButtonItem!

    private let goalsButtonView = UIButton(type: .system)
    private let bgButtonView    = UIButton(type: .system)
    private let hideButtonView  = UIButton(type: .system)
    private let extraGlassContainer = LiquidGlassView(cornerRadius: 16, intensity: .thin)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Сегодня"
        navigationItem.largeTitleDisplayMode = .always
        setupBackground()
        setupRightButtons()
        setupCollection()
        setupActionBar()
        setupMotivation()
        observe()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        reload()
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

    private func setupRightButtons() {
        configureNavButton(goalsButtonView, icon: "target",                      action: #selector(openGoals))
        configureNavButton(bgButtonView,    icon: "photo.on.rectangle.angled",   action: #selector(chooseBackground))
        configureNavButton(hideButtonView,  icon: "chevron.down",                action: #selector(toggleActionBarButton))

        extraGlassContainer.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.28)
        let btnStack = UIStackView(arrangedSubviews: [goalsButtonView, bgButtonView, hideButtonView])
        btnStack.spacing = 2
        extraGlassContainer.contentView.addSubview(btnStack)
        btnStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)) }
        extraGlassContainer.snp.makeConstraints { $0.height.equalTo(36) }

        let extraBarItem = UIBarButtonItem(customView: extraGlassContainer)
        let notifBarItem = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"),
                                           style: .plain, target: self,
                                           action: #selector(openNotifications))
        let plusButton   = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                           style: .plain, target: self,
                                           action: #selector(addTask))

        let navBarLongPress = UILongPressGestureRecognizer(target: self, action: #selector(toggleExtraButtons))
        navBarLongPress.minimumPressDuration = 0.6
        navigationController?.navigationBar.addGestureRecognizer(navBarLongPress)

        navigationItem.leftBarButtonItem  = notifBarItem
        navigationItem.rightBarButtonItems = [plusButton, extraBarItem]
    }

    private func configureNavButton(_ button: UIButton, icon: String, action: Selector) {
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .label
        button.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func openNotifications() {
        let vc = NotificationsCenterViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    @objc private func toggleExtraButtons(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        extraButtonsHidden.toggle()

        let targetAlpha: CGFloat = extraButtonsHidden ? 0 : 1
        let feedback: UIImpactFeedbackGenerator.FeedbackStyle = extraButtonsHidden ? .heavy : .medium

        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            self.extraGlassContainer.alpha = targetAlpha
        }
        UIImpactFeedbackGenerator(style: feedback).impactOccurred()
    }

    private func setupCollection() {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1)))
            item.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(150)),
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)

            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60)),
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delaysContentTouches = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(TaskCell.self, forCellWithReuseIdentifier: TaskCell.reuseID)
        collectionView.register(ProgressHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ProgressHeaderView.reuseID)
        collectionView.contentInset.bottom = 140
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupActionBar() {
        actionBar.layer.cornerRadius = 28
        actionBar.layer.cornerCurve = .continuous
        actionBar.clipsToBounds = true
        actionBar.layer.borderWidth = 0.5
        actionBar.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(actionBar)
        actionBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(124)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-8)
        }

        let coach = makeMiniButton(title: "ИИ Тренер", icon: "bolt.fill", action: #selector(openChat))
        let plan = makeMiniButton(title: "Мой план", icon: "list.bullet.rectangle.portrait", action: #selector(openPlan))
        let topRow = UIStackView(arrangedSubviews: [coach, plan])
        topRow.distribution = .fillEqually
        topRow.spacing = 10

        finishButton.setTitle("Завершить день", for: .normal)
        finishButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        finishButton.setTitleColor(.systemBackground, for: .normal)
        finishButton.backgroundColor = .systemGreen
        finishButton.layer.cornerRadius = 18
        finishButton.layer.cornerCurve = .continuous
        finishButton.addTarget(self, action: #selector(finishDay), for: .touchUpInside)
        finishButton.setImage(UIImage(systemName: "checkmark.seal.fill"), for: .normal)
        finishButton.tintColor = .systemBackground
        finishButton.configuration = nil
        finishButton.imageEdgeInsets = .init(top: 0, left: -6, bottom: 0, right: 6)

        let stack = UIStackView(arrangedSubviews: [topRow, finishButton])
        stack.axis = .vertical
        stack.spacing = 10
        actionBar.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(14) }
        finishButton.snp.makeConstraints { $0.height.equalTo(48) }
    }

    private func setupMotivation() {
        motivationLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        motivationLabel.textColor = .secondaryLabel
        motivationLabel.textAlignment = .center
        motivationLabel.numberOfLines = 0
        view.addSubview(motivationLabel)
        motivationLabel.snp.makeConstraints {
            $0.bottom.equalTo(actionBar.snp.top).offset(-12)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
        updateMotivation()
    }

    private func updateMotivation() {
        motivationLabel.text = DataManager.shared.motivationalMessage
    }

    private func makeMiniButton(title: String, icon: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func observe() {
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .steelTasksChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
    }

    func toggleActionBar() {
        actionBarHidden.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        updateActionBarPosition(animated: true)
    }

    private func updateActionBarPosition(animated: Bool) {
        let offset: CGFloat = actionBarHidden ? 220 : -8
        actionBar.snp.updateConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(offset)
        }
        collectionView.contentInset.bottom = actionBarHidden ? 20 : 140

        hideButtonView.setImage(UIImage(systemName: actionBarHidden ? "chevron.up" : "chevron.down"), for: .normal)

        if animated {
            UIView.animate(
                withDuration: 0.6,
                delay: 0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.15,
                options: .curveEaseOut
            ) {
                self.view.layoutIfNeeded()
                self.actionBar.alpha = self.actionBarHidden ? 0.4 : 1.0
            }
        } else {
            actionBar.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    @objc private func toggleActionBarButton() {
        toggleActionBar()
    }

    @objc private func reload() {
        tasks = DataManager.shared.fetchTasks()
        collectionView.reloadData()
        updateMotivation()
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    @objc private func addTask() {
        let vc = AddTaskViewController()
        presentSheet(UINavigationController(rootViewController: vc))
    }

    @objc private func chooseBackground() {
        BackgroundPicker.shared.present(from: self)
    }

    @objc private func openChat() {
        let vc = AIChatViewController()
        let nav = UINavigationController(rootViewController: vc)
        presentSheet(nav)
    }

    @objc private func openPlan() {
        let vc = PlanViewController()
        vc.hero.isEnabled = true
        let nav = UINavigationController(rootViewController: vc)
        nav.hero.isEnabled = true
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func presentSheet(_ vc: UIViewController) {
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(vc, animated: true)
    }

    @objc private func finishDay() {
        let progress = DataManager.shared.taskProgress

        guard progress.total > 0 else {
            SPIndicator.present(title: "Нет заданий", message: "Добавьте задания на сегодня", preset: .error, haptic: .error)
            return
        }

        guard progress.done > 0 else {
            SPIndicator.present(title: "Ничего не выполнено", message: "Выполните хотя бы одно задание", preset: .error, haptic: .error)
            return
        }

        UIImpactFeedbackGenerator.tap(.heavy)
        DataManager.shared.completeDay()
        let streak = DataManager.shared.settings.streakDays
        if progress.done == progress.total {
            SPIndicator.present(title: "Идеальный день!", message: "Серия: \(streak)", preset: .done, haptic: .success)
        } else {
            SPIndicator.present(title: "День закрыт", message: "Серия: \(streak)", preset: .done, haptic: .success)
        }

        if TelegramManager.shared.isConfigured {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            let t = fmt.string(from: Date())
            Task { await TelegramManager.shared.sendReport(timeLabel: t) }
        }
    }
}

extension TodayViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        tasks.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TaskCell.reuseID, for: indexPath) as! TaskCell
        cell.configure(with: tasks[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ProgressHeaderView.reuseID, for: indexPath) as! ProgressHeaderView
        let progress = DataManager.shared.taskProgress
        header.configure(done: progress.done, total: progress.total, animated: false)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let task = tasks[indexPath.item]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let detailVC = TaskDetailViewController(task: task, wasCompleted: task.isCompleted)
        detailVC.modalPresentationStyle = .overCurrentContext
        detailVC.modalTransitionStyle = .crossDissolve

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(detailVC, animated: false)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let task = tasks[indexPath.item]
        guard !task.isLocked else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu(children: []) }
            let edit = UIAction(title: "Изменить", image: UIImage(systemName: "pencil")) { _ in
                self.presentEditTask(task)
            }
            let delete = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                DataManager.shared.removeTask(task)
            }
            return UIMenu(children: [edit, delete])
        }
    }

    private func presentEditTask(_ task: DailyTask) {
        let vc = EditNameIconViewController(name: task.title, icon: task.iconName) { [weak self] newName, newIcon in
            task.title = newName
            task.iconName = newIcon
            try? DataManager.shared.context.save()
            NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
            SPIndicator.present(title: "Сохранено", preset: .done, haptic: .success)
            self?.reload()
        }
        let nav = UINavigationController(rootViewController: vc)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    @objc private func openGoals() {
        let goalsVC = GoalsViewController()
        navigationController?.pushViewController(goalsVC, animated: true)
    }
}
