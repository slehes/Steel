import UIKit
import SnapKit
import SPIndicator
import SwiftData

final class HabitsViewController: UIViewController {
    private var goodHabits: [Habit] = []
    private var badHabits: [Habit] = []
    private let backgroundView = PersonalBackgroundView()
    private var collectionView: UICollectionView!
    private let emptyView = UILabel()

    private enum Section: Int, CaseIterable {
        case good = 0
        case bad  = 1

        var category: HabitCategory {
            switch self {
            case .good: return .good
            case .bad:  return .bad
            }
        }

        var title: String { category.pluralTitle }
        var icon: String   { category.systemImage }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Привычки"
        navigationItem.largeTitleDisplayMode = .always
        setupBackground()
        setupRightButton()
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
        let plusButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addHabit)
        )
        navigationItem.rightBarButtonItem = plusButton
    }

    private func setupCollection() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else { return nil }
            let item = NSCollectionLayoutItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(190)),
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 14
            section.contentInsets = .init(top: 8, leading: 16, bottom: 24, trailing: 16)

            // Заголовок секции («Полезные» / «Вредные») с красивой стеклянной плашкой
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56)),
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            header.pinToVisibleBounds = false
            section.boundarySupplementaryItems = [header]
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(HabitCell.self, forCellWithReuseIdentifier: HabitCell.reuseID)
        collectionView.register(
            HabitSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: HabitSectionHeader.reuseID
        )
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
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
        let grouped = DataManager.shared.fetchHabitsGrouped()
        goodHabits = grouped.good
        badHabits  = grouped.bad
        collectionView.reloadData()
        emptyView.isHidden = !(goodHabits.isEmpty && badHabits.isEmpty)
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    @objc private func addHabit() {
        let vc = AddHabitViewController()
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
        // Для полезных привычек «relapse» не имеет смысла — там считаем «отмеченные дни».
        // Используем тот же метод, что и для вредных, но сбрасываем streakStart,
        // имитируя «сделал сегодня». Это визуально обновляет счётчик.
        habit.resetStreak()
        try? DataManager.shared.context.save()
        UIImpactFeedbackGenerator.tap(.light)
        SPIndicator.present(title: "День засчитан", message: "Так держать", preset: .done, haptic: .success)
        reload()
    }
}

extension HabitsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int { Section.allCases.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .good: return goodHabits.count
        case .bad:  return badHabits.count
        case .none: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HabitCell.reuseID, for: indexPath) as! HabitCell
        let habit: Habit
        switch Section(rawValue: indexPath.section) {
        case .good: habit = goodHabits[indexPath.item]
        case .bad:  habit = badHabits[indexPath.item]
        case .none: return cell
        }
        cell.configure(with: habit)
        cell.onRelapse = { [weak self, weak cell] in
            self?.relapse(habit, cell: cell)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: HabitSectionHeader.reuseID,
            for: indexPath
        ) as! HabitSectionHeader
        let section = Section(rawValue: indexPath.section) ?? .good
        let count: Int
        switch section {
        case .good: count = goodHabits.count
        case .bad:  count = badHabits.count
        }
        header.configure(title: section.title, icon: section.icon, count: count)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let habit: Habit
        switch Section(rawValue: indexPath.section) {
        case .good: habit = goodHabits[indexPath.item]
        case .bad:  habit = badHabits[indexPath.item]
        case .none: return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let reset = UIAction(title: "Сбросить", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
                guard let self else { return }
                let cell = collectionView.cellForItem(at: indexPath) as? HabitCell
                self.relapse(habit, cell: cell)
            }
            let delete = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                DataManager.shared.removeHabit(habit)
                self?.reload()
            }
            return UIMenu(children: [reset, delete])
        }
    }
}
