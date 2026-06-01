import UIKit
import PhotosUI
import SPIndicator
import UniformTypeIdentifiers

@MainActor
final class BackgroundPicker: NSObject, PHPickerViewControllerDelegate {
    static let shared = BackgroundPicker()

    private weak var presenter: UIViewController?

    func present(from viewController: UIViewController) {
        presenter = viewController
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        let provider = result.itemProvider
        let screenSize = UIScreen.main.bounds.size

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                Task { @MainActor in
                    let ok = BackgroundManager.shared.setPhoto(image, screenSize: screenSize, dimmed: true)
                    self?.notify(ok)
                }
            }
            return
        }

        let videoTypes = [UTType.movie.identifier, UTType.mpeg4Movie.identifier, UTType.quickTimeMovie.identifier]
        if let type = videoTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
            SPIndicator.present(title: "Обработка видео…", message: "Подождите", haptic: SPIndicatorHaptic.none)
            provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
                guard let url else {
                    Task { @MainActor in self?.notify(false) }
                    return
                }
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                try? FileManager.default.copyItem(at: url, to: temp)
                Task { @MainActor in
                    let ok = await BackgroundManager.shared.setVideo(sourceURL: temp, dimmed: true)
                    try? FileManager.default.removeItem(at: temp)
                    self?.notify(ok)
                }
            }
            return
        }

        notify(false)
    }

    private func notify(_ success: Bool) {
        if success {
            SPIndicator.present(title: "Фон установлен", preset: .done, haptic: .success)
        } else {
            SPIndicator.present(title: "Не удалось", preset: .error, haptic: .error)
        }
    }
}
