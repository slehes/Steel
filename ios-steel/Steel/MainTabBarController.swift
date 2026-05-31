import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

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
