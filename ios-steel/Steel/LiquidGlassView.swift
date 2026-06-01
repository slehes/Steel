import UIKit
import SnapKit

/// «Жидкое стекло» — переиспользуемая стеклянная карточка.
///
/// Внутри:
/// 1. UIVisualEffectView с тонким материалом — это даёт честный blur системного материала
///    (виден фон, но приглушённо).
/// 2. CAGradientLayer с белым градиентом 6% → 0% поверх — это «блик» сверху.
/// 3. Внутренняя рамка из 1px белой линии на 18% alpha — стеклянная кромка.
/// 4. Внешняя обводка тенью через contentView.dropShadow.
///
/// Использовать как обычный UIView:
///     let glass = LiquidGlassView(cornerRadius: 22, intensity: .regular)
///     glass.contentView.addSubview(myLabel)
///
/// Интенсивность (`intensity`) управляет толщиной blur и прозрачностью блика.
final class LiquidGlassView: UIView {

    enum Intensity {
        case thin        // лёгкий blur, подходит для inline-карточек
        case regular     // стандартный, для основных карточек
        case heavy       // максимальный blur для модалок и навигации

        fileprivate var blurStyle: UIBlurEffect.Style {
            switch self {
            case .thin:    return .systemThinMaterial
            case .regular: return .systemUltraThinMaterial
            case .heavy:   return .systemThickMaterial
            }
        }

        fileprivate var highlightAlpha: CGFloat {
            switch self {
            case .thin:    return 0.10
            case .regular: return 0.16
            case .heavy:   return 0.22
            }
        }
    }

    private let visualEffectView: UIVisualEffectView
    private let highlightLayer = CAGradientLayer()
    private let innerBorderLayer = CAShapeLayer()

    /// Сюда добавлять subviews (это `contentView` UIVisualEffectView).
    var contentView: UIView { visualEffectView.contentView }

    var cornerRadius: CGFloat = 22 {
        didSet { applyShape() }
    }

    var intensity: Intensity = .regular {
        didSet { applyIntensity() }
    }

    init(cornerRadius: CGFloat = 22, intensity: Intensity = .regular) {
        self.visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: intensity.blurStyle))
        self.cornerRadius = cornerRadius
        self.intensity = intensity
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = false
        backgroundColor = .clear

        addSubview(visualEffectView)
        visualEffectView.snp.makeConstraints { $0.edges.equalToSuperview() }
        visualEffectView.layer.cornerRadius = cornerRadius
        visualEffectView.layer.cornerCurve = .continuous
        visualEffectView.clipsToBounds = true

        // Блик: прозрачный градиент сверху → вниз, с верхним белым highlight
        highlightLayer.colors = [
            UIColor.white.withAlphaComponent(intensity.highlightAlpha).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        highlightLayer.locations = [0.0, 0.5]
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        highlightLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        visualEffectView.contentView.layer.addSublayer(highlightLayer)

        // Внутренняя кромка для эффекта «стекла»
        innerBorderLayer.fillColor = nil
        innerBorderLayer.strokeColor = UIColor.white.withAlphaComponent(0.22).cgColor
        innerBorderLayer.lineWidth = 0.5
        visualEffectView.contentView.layer.addSublayer(innerBorderLayer)

        applyShape()
    }

    private func applyIntensity() {
        // UIBlurEffect применяется через замену effect-а — для скорости делаем fade
        UIView.transition(with: visualEffectView, duration: 0.25, options: .transitionCrossDissolve) {
            self.visualEffectView.effect = UIBlurEffect(style: self.intensity.blurStyle)
        }
        highlightLayer.colors = [
            UIColor.white.withAlphaComponent(self.intensity.highlightAlpha).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
    }

    private func applyShape() {
        layer.cornerRadius = cornerRadius
        visualEffectView.layer.cornerRadius = cornerRadius
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlightLayer.frame = visualEffectView.contentView.bounds
        let inset: CGFloat = 0.5
        let path = UIBezierPath(
            roundedRect: visualEffectView.contentView.bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: max(0, cornerRadius - inset)
        )
        innerBorderLayer.path = path.cgPath
        innerBorderLayer.frame = visualEffectView.contentView.bounds
    }
}

// MARK: - Удобный модификатор для «жидкой» стилизации UIView

extension UIView {
    /// Применяет стандартный «жидкий стеклянный» стиль к UIView.
    /// Используется когда нужна быстрая стеклянная обёртка без композиции.
    func applyLiquidGlass(cornerRadius: CGFloat = 22, intensity: LiquidGlassView.Intensity = .regular) {
        backgroundColor = .clear
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor

        // Внутренний CAGradientLayer-блик (если уже не добавлен)
        if layer.sublayers?.first(where: { $0.name == "liquidHighlight" }) == nil {
            let grad = CAGradientLayer()
            grad.name = "liquidHighlight"
            grad.colors = [
                UIColor.white.withAlphaComponent(intensity.highlightAlpha).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor
            ]
            grad.startPoint = CGPoint(x: 0.5, y: 0)
            grad.endPoint = CGPoint(x: 0.5, y: 1)
            grad.frame = bounds
            grad.cornerRadius = cornerRadius
            layer.addSublayer(grad)
        }
    }
}
