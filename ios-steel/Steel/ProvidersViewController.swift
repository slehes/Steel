import UIKit
import SnapKit
import SPIndicator

final class ProvidersViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Провайдеры"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setup()
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

    private func setup() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)

        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true

        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
        }

        setupGroqSection()
        setupGeminiSection()
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func setupGroqSection() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let headerRow = makeProviderHeader(name: "Groq", icon: "bolt.horizontal.fill", color: .systemGreen)
        stack.addArrangedSubview(headerRow)

        let sep1 = separator()
        stack.addArrangedSubview(sep1)

        let keyField = UITextField()
        keyField.placeholder = "gsk_..."
        keyField.font = UIFont.preferredFont(forTextStyle: .body)
        keyField.textColor = .label
        keyField.text = KeychainHelper.groqAPIKey
        keyField.isSecureTextEntry = true
        keyField.autocapitalizationType = .none
        keyField.autocorrectionType = .no
        keyField.returnKeyType = .done
        keyField.delegate = self
        keyField.tag = 100

        let keyLabel = UILabel()
        keyLabel.text = "API Key"
        keyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        keyLabel.textColor = .label

        let keyRow = UIStackView(arrangedSubviews: [keyLabel, UIView(), keyField])
        keyRow.alignment = .center
        keyRow.isLayoutMarginsRelativeArrangement = true
        keyRow.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)
        stack.addArrangedSubview(keyRow)

        let hint = UILabel()
        hint.text = "console.groq.com — Llama 3.3 70B"
        hint.font = UIFont.preferredFont(forTextStyle: .caption2)
        hint.textColor = .tertiaryLabel
        let hintRow = UIStackView(arrangedSubviews: [hint])
        hintRow.isLayoutMarginsRelativeArrangement = true
        hintRow.layoutMargins = .init(top: 0, left: 16, bottom: 12, right: 16)
        stack.addArrangedSubview(hintRow)

        contentStack.addArrangedSubview(card)
    }

    private func setupGeminiSection() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let headerRow = makeProviderHeader(name: "Google Gemini", icon: "sparkles", color: .systemBlue)
        stack.addArrangedSubview(headerRow)

        let sep1 = separator()
        stack.addArrangedSubview(sep1)

        let keyField = UITextField()
        keyField.placeholder = "AIza..."
        keyField.font = UIFont.preferredFont(forTextStyle: .body)
        keyField.textColor = .label
        keyField.text = KeychainHelper.geminiAPIKey
        keyField.isSecureTextEntry = true
        keyField.autocapitalizationType = .none
        keyField.autocorrectionType = .no
        keyField.returnKeyType = .done
        keyField.delegate = self
        keyField.tag = 200

        let keyLabel = UILabel()
        keyLabel.text = "API Key"
        keyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        keyLabel.textColor = .label

        let keyRow = UIStackView(arrangedSubviews: [keyLabel, UIView(), keyField])
        keyRow.alignment = .center
        keyRow.isLayoutMarginsRelativeArrangement = true
        keyRow.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)
        stack.addArrangedSubview(keyRow)

        let hint = UILabel()
        hint.text = "aistudio.google.com — Gemini 2.0 Flash"
        hint.font = UIFont.preferredFont(forTextStyle: .caption2)
        hint.textColor = .tertiaryLabel
        let hintRow = UIStackView(arrangedSubviews: [hint])
        hintRow.isLayoutMarginsRelativeArrangement = true
        hintRow.layoutMargins = .init(top: 0, left: 16, bottom: 12, right: 16)
        stack.addArrangedSubview(hintRow)

        contentStack.addArrangedSubview(card)
    }

    private func makeProviderHeader(name: String, icon: String, color: UIColor) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconView.layer.cornerRadius = 8
        iconView.layer.cornerCurve = .continuous
        iconView.backgroundColor = color
        iconView.snp.makeConstraints { $0.size.equalTo(28) }

        let label = UILabel()
        label.text = name
        label.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        label.textColor = .label

        let row = UIStackView(arrangedSubviews: [iconView, label, UIView()])
        row.alignment = .center
        row.spacing = 10
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)
        return row
    }

    private func makeCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        return card
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.snp.makeConstraints { $0.height.equalTo(0.5) }
        return line
    }
}

extension ProvidersViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        let key = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        switch textField.tag {
        case 100:
            KeychainHelper.setGroqAPIKey(key)
            if !key.isEmpty {
                SPIndicator.present(title: "Groq ключ сохранён", preset: .done, haptic: .success)
            }
        case 200:
            KeychainHelper.setGeminiAPIKey(key)
            if !key.isEmpty {
                SPIndicator.present(title: "Gemini ключ сохранён", preset: .done, haptic: .success)
            }
        default:
            break
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
