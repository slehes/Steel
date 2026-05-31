import UIKit
import SnapKit
import Hero

final class PlanViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let backgroundView = PersonalBackgroundView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let emptyView = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Мой план"
        setupBackground()
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
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

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.hero.id = "planCard"
        scrollView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(30)
            $0.width.equalTo(view).offset(-40)
        }

        titleLabel.text = "Программа"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2).withWeight(.bold)
        titleLabel.textColor = .label

        bodyLabel.numberOfLines = 0
        bodyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.textColor = .label

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 14
        card.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(22) }

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
        if let plan = DataManager.shared.currentPlan(), !plan.body.isEmpty {
            bodyLabel.text = plan.body
            scrollView.isHidden = false
            emptyView.isHidden = true
        } else {
            scrollView.isHidden = true
            emptyView.isHidden = false
        }
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
