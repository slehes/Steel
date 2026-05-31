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
    private let pinnedTitleLabel = UILabel()
    private var actionBarHidden = false
    private var actionBarOriginalBottom: Constraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupBackground()
        setupPinnedTitle()
        setupNavigation()
        setupCollection()
        setupActionBar()
        observe()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        navigationController?.navigationBar.isHidden = true
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
        navigationController?.navigationBar.isHidden = false
    }

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func setupPinnedTitle() {
        pinnedTitleLabel.text = "Сегодня"
        pinnedTitleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        pinnedTitleLabel.textColor = .label
        view.addSubview(pinnedTitleLabel)
        pinnedTitleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).inset(8)
            $0.leading.equalToSuperview().inset(20)
        }
    }

    private func setupNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addTask)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "photo.on.rectangle.angled"),
            style: .plain,
            target: self,
            action: #selector(chooseBackground)
        )
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
        collectionView.contentInset.top = 44
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
            actionBarOriginalBottom = $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(8).constraint
            $0.height.equalTo(124)
        }

        let coach = makeMiniButton(title: "ИИ Тренер", icon: "bolt.fill", action: #selector(openChat))
        let plan = makeMiniButton(title: "Мой план", icon: "list.bullet.rectangle.portrait", action: #selector(openPlan))
        let topRow = UIStackView(arrangedSubviews: [coach, plan])
        topRow.distribution = .fillEqually
        topRow.spacing = 10

        finishButton.setTitle("Завершить день", for: .normal)
        finishButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        finishButton.setTitleColor(.systemBackground, for: .normal)
        finishButton.backgroundColor = .label
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
        let offset: CGFloat = actionBarHidden ? 160 : -8
        actionBar.snp.updateConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(offset)
        }
        collectionView.contentInset.bottom = actionBarHidden ? 20 : 140
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func toggleActionBarButton() {
        toggleActionBar()
    }

    @objc private func reload() {
        tasks = DataManager.shared.fetchTasks()
        collectionView.reloadData()
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
        guard progress.total > 0 else { return }
        UIImpactFeedbackGenerator.tap(.heavy)
        DataManager.shared.completeDay()
        let streak = DataManager.shared.settings.streakDays
        SPIndicator.present(title: "День закрыт", message: "Серия: \(streak)", preset: .done, haptic: .success)
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
        let wasCompleted = task.isCompleted
        DataManager.shared.toggleTask(task)
        UIImpactFeedbackGenerator.tap(.medium)

        if let cell = collectionView.cellForItem(at: indexPath) as? TaskCell {
            cell.configureAnimated(with: task, wasCompleted: wasCompleted)
        }

        let progress = DataManager.shared.taskProgress
        if let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? ProgressHeaderView {
            header.configure(done: progress.done, total: progress.total, animated: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.tasks = DataManager.shared.fetchTasks()
            collectionView.reloadItems(at: [indexPath])
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let task = tasks[indexPath.item]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let delete = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                DataManager.shared.removeTask(task)
            }
            return UIMenu(children: [delete])
        }
    }
}
