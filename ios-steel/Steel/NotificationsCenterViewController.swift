import UIKit
import SnapKit

final class NotificationsCenterViewController: UIViewController {

    private enum Filter: Int, CaseIterable {
        case all, coach, achievement, birthday

        var title: String {
            switch self {
            case .all:         return "Все"
            case .coach:       return "Тренер"
            case .achievement: return "Начисления"
            case .birthday:    return "Поздравления"
            }
        }

        var notifType: SteelNotifType? {
            switch self {
            case .all:         return nil
            case .coach:       return .coach
            case .achievement: return .achievement
            case .birthday:    return .birthday
            }
        }
    }

    private var currentFilter: Filter = .all
    private var displayed: [SteelLocalNotification] = []

    private let backgroundView = PersonalBackgroundView()
    private let filterScrollView = UIScrollView()
    private var filterButtons: [UIButton] = []
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Уведомления"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Прочитано", style: .plain, target: self, action: #selector(markAllRead))
        setupBackground()
        setupFilters()
        setupTable()
        setupEmpty()
        reload()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .steelNotificationsChanged, object: nil)
    }

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func setupFilters() {
        filterScrollView.showsHorizontalScrollIndicator = false
        filterScrollView.backgroundColor = .clear
        view.addSubview(filterScrollView)
        filterScrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(44)
        }

        let stack = UIStackView()
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        filterScrollView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalToSuperview()
        }

        for filter in Filter.allCases {
            let glass = LiquidGlassView(cornerRadius: 14, intensity: .thin)
            glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.3)

            let btn = UIButton(type: .system)
            btn.setTitle(filter.title, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            btn.tag = filter.rawValue
            btn.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)

            glass.contentView.addSubview(btn)
            btn.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)) }
            glass.snp.makeConstraints { $0.height.equalTo(36) }

            stack.addArrangedSubview(glass)
            filterButtons.append(btn)
        }

        updateFilterStyle()
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.register(NotifCell.self, forCellReuseIdentifier: NotifCell.reuseID)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(filterScrollView.snp.bottom).offset(8)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupEmpty() {
        emptyLabel.text = "Уведомлений пока нет"
        emptyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    @objc private func reload() {
        let all = SteelNotificationStore.shared.all
        if let type = currentFilter.notifType {
            displayed = all.filter { $0.type == type }
        } else {
            displayed = all
        }
        tableView.reloadData()
        emptyLabel.isHidden = !displayed.isEmpty
    }

    @objc private func filterTapped(_ sender: UIButton) {
        guard let filter = Filter(rawValue: sender.tag) else { return }
        currentFilter = filter
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateFilterStyle()
        reload()
    }

    @objc private func markAllRead() {
        SteelNotificationStore.shared.markAllRead()
        tableView.reloadData()
    }

    private func updateFilterStyle() {
        for (i, btn) in filterButtons.enumerated() {
            let isSelected = i == currentFilter.rawValue
            btn.setTitleColor(isSelected ? .label : .secondaryLabel, for: .normal)
            if let glass = btn.superview as? LiquidGlassView {
                glass.backgroundColor = isSelected
                    ? UIColor.label.withAlphaComponent(0.12)
                    : UIColor.secondarySystemBackground.withAlphaComponent(0.28)
            }
        }
    }
}

extension NotificationsCenterViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { displayed.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NotifCell.reuseID, for: indexPath) as! NotifCell
        cell.configure(with: displayed[indexPath.row])
        return cell
    }
}

private final class NotifCell: UITableViewCell {
    static let reuseID = "NotifCell"

    private let glass     = LiquidGlassView(cornerRadius: 16, intensity: .thin)
    private let iconBack  = UIView()
    private let iconView  = UIImageView()
    private let titleLbl  = UILabel()
    private let bodyLbl   = UILabel()
    private let timeLbl   = UILabel()
    private let dot       = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.32)
        contentView.addSubview(glass)
        glass.snp.makeConstraints {
            $0.top.equalToSuperview().inset(6)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(6)
        }

        let c = glass.contentView
        iconBack.layer.cornerRadius = 10; iconBack.layer.cornerCurve = .continuous; iconBack.clipsToBounds = true
        iconView.contentMode = .center; iconView.tintColor = .white
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconBack.addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }
        c.addSubview(iconBack)
        iconBack.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(14)
            $0.top.equalToSuperview().inset(14)
            $0.width.height.equalTo(34)
        }

        titleLbl.font = UIFont.systemFont(ofSize: 14, weight: .semibold); titleLbl.textColor = .label
        bodyLbl.font  = UIFont.systemFont(ofSize: 13, weight: .regular);  bodyLbl.textColor  = .secondaryLabel; bodyLbl.numberOfLines = 2
        timeLbl.font  = UIFont.systemFont(ofSize: 11, weight: .regular);  timeLbl.textColor  = .tertiaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLbl, bodyLbl, timeLbl])
        textStack.axis = .vertical; textStack.spacing = 3
        c.addSubview(textStack)
        textStack.snp.makeConstraints {
            $0.leading.equalTo(iconBack.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().inset(14)
            $0.centerY.equalTo(iconBack)
        }

        dot.backgroundColor = .systemBlue; dot.layer.cornerRadius = 4
        c.addSubview(dot)
        dot.snp.makeConstraints { $0.trailing.equalToSuperview().inset(14); $0.top.equalToSuperview().inset(14); $0.width.height.equalTo(8) }

        glass.snp.makeConstraints { _ in }
        iconBack.snp.updateConstraints { $0.bottom.lessThanOrEqualTo(c).inset(14) }
    }

    func configure(with n: SteelLocalNotification) {
        iconBack.backgroundColor = n.type.color
        iconView.image  = UIImage(systemName: n.type.icon)
        titleLbl.text   = n.title
        bodyLbl.text    = n.body
        dot.isHidden    = n.isRead

        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM, HH:mm"
        fmt.locale = Locale(identifier: "ru_RU")
        timeLbl.text = fmt.string(from: n.date)
    }
}
