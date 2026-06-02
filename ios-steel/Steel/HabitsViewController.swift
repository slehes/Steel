import UIKit
import SnapKit
import SPIndicator
import SwiftData

final class HabitsViewController: UIViewController {
    private var goodHabits: [Habit] = []
    private var badHabits: [Habit] = []
    private var selectedTab: HabitCategory = .bad

    private let backgroundView = PersonalBackgroundView()
    private var collectionView: UICollectionView!
    private let emptyView = UILabel()

    private let segmentedControl = UISegmentedControl(items: [
        HabitCategory.bad.pluralTitle,   // Вредные — index 0
        HabitCategory.good.pluralTitle   // Полезные — index 1
    ])
    private let segmentGlass = LiquidGlassView(cornerRadius: 16, intensity: .regular)

    private var isReloading = false

    private var currentHabits: [Habit] {
        selectedTab == .good ? goodHabits : badHabits
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Привычки"
        navigationItem.largeTitleDisplayMode = .always
        setupBackground()
        setupRightButton()
        setupSegmentedControl()
        setupCollection()
        setupEmpty()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .steelHabitsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
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

    private func setupRightButton() {
        let plusButton  = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                          style: .plain, target: self, action: #selector(addHabit))
        let notifButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"),
                                          style: .plain, target: self, action: #selector(openNotifications))
        navigationItem.rightBarButtonItem = plusButton
        navigationItem.leftBarButtonItem  = notifButton
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

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0 // Вредные по умолчанию
        segmentedControl.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        applySegmentStyle()

        segmentGlass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.35)
        segmentGlass.contentView.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { $0.edges.equalToSuperview().inset(5) }

        view.addSubview(segmentGlass)
        segmentGlass.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(48)
        }
    }

    private func applySegmentStyle() {
        let tint: UIColor = selectedTab == .good ? .systemGreen : .systemRed
        segmentedControl.selectedSegmentTintColor = tint
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14, weight: .semibold)],
            for: .normal
        )
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 14, weight: .bold)],
            for: .selected
        )
    }

    private func setupCollection() {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, _ in
            guard self != nil else { return nil }
            let item = NSCollectionLayoutItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(200)),
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 14
            section.contentInsets = .init(top: 8, leading: 16, bottom: 24, trailing: 16)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(HabitCell.self, forCellWithReuseIdentifier: HabitCell.reuseID)
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.top.equalTo(segmentGlass.snp.bottom).offset(12)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupEmpty() {
        emptyView.text = "Пока пусто.\nНажми «+» чтобы добавить привычку."
        emptyView.numberOfLines = 0
        emptyView.textAlignment = .center
        emptyView.font = UIFont.preferredFont(forTextStyle: .body)
        emptyView.textColor = .secondaryLabel
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { $0.center.equalToSuperview() }
        emptyView.isHidden = true
    }

    @objc private func reload() {
        guard !isReloading else {
            DispatchQueue.main.async { [weak self] in self?.reload() }
            return
        }
        isReloading = true
        defer { isReloading = false }

        let grouped = DataManager.shared.fetchHabitsGrouped()
        goodHabits = grouped.good
        badHabits  = grouped.bad

        guard collectionView != nil else { return }

        collectionView.reloadData()
        updateEmptyState()
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func updateEmptyState() {
        let habits = currentHabits
        emptyView.isHidden = !habits.isEmpty
        if habits.isEmpty {
            emptyView.text = selectedTab == .good
                ? "Нет полезных привычек.\nНажми «+» чтобы добавить."
                : "Нет вредных привычек.\nНажми «+» чтобы добавить."
        }
    }

    @objc private func tabChanged() {
        selectedTab = segmentedControl.selectedSegmentIndex == 1 ? .good : .bad
        applySegmentStyle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateEmptyState()
        UIView.transition(with: collectionView, duration: 0.3, options: .transitionCrossDissolve) {
            self.collectionView.reloadData()
        }
    }

    @objc private func addHabit() {
        let vc = AddHabitViewController(initialCategory: selectedTab)
        let nav = UINavigationController(rootViewController: vc)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    private func relapse(_ habit: Habit, cell: HabitCell?) {
        UINotificationFeedbackGenerator.notify(.warning)
        habit.relapse()
        try? DataManager.shared.context.save()
        cell?.animateRelapse()
        SPIndicator.present(title: "Счётчик сброшен", message: "Начинай заново", preset: .error, haptic: .error)
        reload()
    }

    private func markDayDone(_ habit: Habit, cell: HabitCell?) {
        habit.resetStreak()
        try? DataManager.shared.context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SPIndicator.present(title: "День засчитан", message: "Так держать", preset: .done, haptic: .success)
        reload()
    }
}


extension HabitsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentHabits.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HabitCell.reuseID, for: indexPath) as! HabitCell

        guard indexPath.item < currentHabits.count else { return cell }
        let habit = currentHabits[indexPath.item]
        cell.configure(with: habit)

        if habit.category == .good {
            cell.onRelapse = { [weak self, weak cell] in
                self?.markDayDone(habit, cell: cell)
            }
        } else {
            cell.onRelapse = { [weak self, weak cell] in
                self?.relapse(habit, cell: cell)
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < currentHabits.count else { return }
        let habit = currentHabits[indexPath.item]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = HabitStreakDetailViewController(habit: habit)
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < currentHabits.count else { return nil }
        let habit = currentHabits[indexPath.item]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let reset = UIAction(title: "Сбросить", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
                guard let self else { return }
                let cell = collectionView.cellForItem(at: indexPath) as? HabitCell
                if habit.category == .good {
                    self.markDayDone(habit, cell: cell)
                } else {
                    self.relapse(habit, cell: cell)
                }
            }
            let delete = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                DataManager.shared.removeHabit(habit)
                self?.reload()
            }
            return UIMenu(children: [reset, delete])
        }
    }
}
