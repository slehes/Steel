import UIKit

final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        let today = makeNav(
            root: TodayViewController(),
            title: "Сегодня",
            image: "flame",
            selected: "flame.fill"
        )
        let habits = makeNav(
            root: HabitsViewController(),
            title: "Привычки",
            image: "shield.lefthalf.filled",
            selected: "shield.fill"
        )
        let profile = makeNav(
            root: ProfileViewController(),
            title: "Профиль",
            image: "person",
            selected: "person.fill"
        )

        viewControllers = [today, habits, profile]

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = .label

        setupLongPressOnTodayTab()
    }

    private func setupLongPressOnTodayTab() {
        guard let todayItem = tabBar.items?.first else { return }
        let todayTabView = tabBar.subviews.first { view in
            if let label = view.subviews.compactMap({ $0 as? UILabel }).first {
                return label.text == todayItem.title
            }
            return false
        }
        guard let targetView = todayTabView else {
            if let firstSubview = tabBar.subviews.first {
                addLongPress(to: firstSubview)
            }
            return
        }
        addLongPress(to: targetView)
    }

    private func addLongPress(to view: UIView) {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleTodayLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        view.addGestureRecognizer(longPress)
    }

    @objc private func handleTodayLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, selectedIndex == 0 else { return }
        if let nav = viewControllers?.first as? UINavigationController,
           let todayVC = nav.viewControllers.first as? TodayViewController {
            todayVC.toggleActionBar()
        }
    }

    private func makeNav(root: UIViewController, title: String, image: String, selected: String) -> UINavigationController {
        root.title = title
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = true
        nav.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: image),
            selectedImage: UIImage(systemName: selected)
        )
        return nav
    }
}
