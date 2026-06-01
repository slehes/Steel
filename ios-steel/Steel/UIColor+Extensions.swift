import UIKit

extension UIColor {
    static var steelPrimary: UIColor { .label }
    static var steelSecondary: UIColor { .secondaryLabel }
    static var steelTertiary: UIColor { .tertiaryLabel }
    static var steelBackground: UIColor { .systemBackground }
    static var steelGrouped: UIColor { .systemGroupedBackground }
    static var steelCard: UIColor { .secondarySystemBackground }
    static var steelSeparator: UIColor { .separator }
    static var steelFill: UIColor { .systemFill }
}

extension UIView {
    func applyCardShadow() {
        layer.shadowColor = UIColor.label.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.masksToBounds = false
    }

    func pinEdges(to other: UIView, inset: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: inset),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -inset),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -inset),
        ])
    }
}

extension UIImpactFeedbackGenerator {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

extension UINotificationFeedbackGenerator {
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach { addArrangedSubview($0) }
    }
}
