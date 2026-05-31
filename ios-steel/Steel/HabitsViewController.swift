import UIKit
import SnapKit
import SPIndicator
import SwiftData

final class HabitsViewController: UIViewController {
    private var habits: [Habit] = []
    private let backgroundView = PersonalBackgroundView()
    private var collectionView: UICollectionView!
    private let headerContainer = UIView()
    private let pinnedTitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupBackground()
        setupHeader()
        setupCollection()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .steelHabitsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
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

    private func setupHeader() {
        headerContainer.backgroundColor = .clear
        view.addSubview(headerContainer)
        headerContainer.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(52)
        }

        pinnedTitleLabel.text = "Привычки"
        pinnedTitleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        pinnedTitleLabel.textColor = .label
        headerContainer.addSubview(pinnedTitleLabel)
        pinnedTitleLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(20)
        }

        let plusButton = UIButton(type: .system)
        plusButton.setImage(UIImage(systemName: "plus"), for: .normal)
        plusButton.tintColor = .label
        plusButton.addTarget(self, action: #selector(addHabit), for: .touchUpInside)
        headerContainer.addSubview(plusButton)
        plusButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(20)
        }
    }

    private func setupCollection() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(190)),
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 14
            section.contentInsets = .init(top: 12, leading: 16, bottom: 30, trailing: 16)
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(HabitCell.self, forCellWithReuseIdentifier: HabitCell.reuseID)
        collectionView.contentInset.top = 56
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @objc private func reload() {
        habits = DataManager.shared.fetchHabits()
        collectionView.reloadData()
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
}

extension HabitsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { habits.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HabitCell.reuseID, for: indexPath) as! HabitCell
        let habit = habits[indexPath.item]
        cell.configure(with: habit)
        cell.onRelapse = { [weak self, weak cell] in
            self?.relapse(habit, cell: cell)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let habit = habits[indexPath.item]
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
