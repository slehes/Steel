import UIKit

final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    private var longPressOverlay: UIView?

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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupLongPressOverlay()
    }

    private func setupLongPressOverlay() {
        longPressOverlay?.removeFromSuperview()

        let tabBarButtons = tabBar.subviews.filter { $0 is UIControl }
        guard let firstButton = tabBarButtons.first else { return }

        let overlay = UIView(frame: firstButton.frame)
        overlay.backgroundColor = .clear
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleTodayLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        overlay.addGestureRecognizer(longPress)
        tabBar.addSubview(overlay)
        longPressOverlay = overlay
    }

    @objc private func handleTodayLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard selectedIndex == 0 else { return }

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
