import UIKit

final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    private var longPressGesture: UILongPressGestureRecognizer?

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

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        tabBar.addGestureRecognizer(longPress)
        longPressGesture = longPress
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let location = gesture.location(in: tabBar)
        guard let items = tabBar.items, !items.isEmpty else { return }

        let tabBarWidth = tabBar.bounds.width
        let itemCount = CGFloat(items.count)
        let itemWidth = tabBarWidth / itemCount

        let firstItemRect = CGRect(x: 0, y: 0, width: itemWidth, height: tabBar.bounds.height)

        if firstItemRect.contains(location) {
            if let nav = viewControllers?.first as? UINavigationController,
               let todayVC = nav.viewControllers.first as? TodayViewController {
                todayVC.toggleActionBar()
            }
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
