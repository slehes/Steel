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

        bubble.layer.cornerRadius = 20
        bubble.layer.cornerCurve = .continuous
        contentView.addSubview(bubble)

        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.lineBreakMode = .byWordWrapping
        bubble.addSubview(messageLabel)
        messageLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalToSuperview().inset(10)
            $0.leading.equalToSuperview().inset(14)
            $0.trailing.equalToSuperview().inset(14)
        }

        bubble.snp.makeConstraints {
            $0.top.equalToSuperview().inset(4)
            $0.bottom.equalToSuperview().inset(4)
            $0.width.lessThanOrEqualTo(contentView.snp.width).multipliedBy(0.75)
            leadingConstraint = $0.leading.equalToSuperview().inset(16).constraint
            trailingConstraint = $0.trailing.lessThanOrEqualToSuperview().inset(16).constraint
        }
    }

    func configure(text: String, isUser: Bool) {
        messageLabel.text = text
        if isUser {
            bubble.backgroundColor = .label
            messageLabel.textColor = .systemBackground
            bubble.layer.borderWidth = 0
            leadingConstraint?.deactivate()
            trailingConstraint?.activate()
            bubble.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(16)
            }
        } else {
            bubble.backgroundColor = .secondarySystemBackground
            messageLabel.textColor = .label
            bubble.layer.borderWidth = 1
            bubble.layer.borderColor = UIColor.separator.cgColor
            trailingConstraint?.deactivate()
            leadingConstraint?.activate()
            bubble.snp.makeConstraints {
                $0.leading.equalToSuperview().inset(16)
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bubble.snp.remakeConstraints {
            $0.top.equalToSuperview().inset(4)
            $0.bottom.equalToSuperview().inset(4)
            $0.width.lessThanOrEqualTo(contentView.snp.width).multipliedBy(0.75)
            leadingConstraint = $0.leading.equalToSuperview().inset(16).constraint
            trailingConstraint = $0.trailing.lessThanOrEqualToSuperview().inset(16).constraint
        }
    }
}
