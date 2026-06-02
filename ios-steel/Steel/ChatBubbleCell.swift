import UIKit
import SnapKit

final class ChatBubbleCell: UITableViewCell {
    static let reuseID = "ChatBubbleCell"

    private let bubble = UIView()
    private let messageLabel = UILabel()
    private var leadingConstraint: Constraint?
    private var trailingConstraint: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        bubble.layer.cornerRadius = 18
        bubble.layer.cornerCurve = .continuous
        contentView.addSubview(bubble)

        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        messageLabel.lineBreakMode = .byWordWrapping
        bubble.addSubview(messageLabel)
        messageLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalToSuperview().inset(10)
            $0.leading.equalToSuperview().inset(14)
            $0.trailing.equalToSuperview().inset(14)
        }

        bubble.snp.makeConstraints {
            $0.top.equalToSuperview().inset(3)
            $0.bottom.equalToSuperview().inset(3)
            $0.width.lessThanOrEqualTo(contentView.snp.width).multipliedBy(0.78)
            leadingConstraint = $0.leading.equalToSuperview().inset(16).constraint
            trailingConstraint = $0.trailing.lessThanOrEqualToSuperview().inset(16).constraint
        }
    }

    func configure(text: String, isUser: Bool) {
        messageLabel.text = text

        let maxWidth = UIScreen.main.bounds.width * 0.78 - 28 // bubble width - bubble padding
        messageLabel.preferredMaxLayoutWidth = maxWidth

        if isUser {
            bubble.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            bubble.layer.borderWidth = 0
            leadingConstraint?.deactivate()
            trailingConstraint?.activate()
        } else {
            let blurEffect = UIBlurEffect(style: .systemThickMaterial)
            let blurBg = UIVisualEffectView(effect: blurEffect)
            blurBg.layer.cornerRadius = 18
            blurBg.layer.cornerCurve = .continuous
            blurBg.clipsToBounds = true

            bubble.subviews.filter { $0 != messageLabel }.forEach { $0.removeFromSuperview() }
            bubble.insertSubview(blurBg, at: 0)
            blurBg.snp.makeConstraints { $0.edges.equalToSuperview() }
            bubble.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.85)
            messageLabel.textColor = .label
            messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            bubble.layer.borderWidth = 0.5
            bubble.layer.borderColor = UIColor.separator.cgColor
            trailingConstraint?.deactivate()
            leadingConstraint?.activate()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.preferredMaxLayoutWidth = 0
        bubble.subviews.filter { $0 != messageLabel }.forEach { $0.removeFromSuperview() }
        bubble.snp.remakeConstraints {
            $0.top.equalToSuperview().inset(3)
            $0.bottom.equalToSuperview().inset(3)
            $0.width.lessThanOrEqualTo(contentView.snp.width).multipliedBy(0.78)
            leadingConstraint = $0.leading.equalToSuperview().inset(16).constraint
            trailingConstraint = $0.trailing.lessThanOrEqualToSuperview().inset(16).constraint
        }
    }
}
