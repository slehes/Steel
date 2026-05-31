import UIKit
import AVFoundation
import CoreMedia
import CoreImage
import UniformTypeIdentifiers

enum MediaProcessor {
    static let supportedImageTypes: Set<String> = ["public.jpeg", "public.png", "public.heic", "public.heif", "com.compuserve.gif"]
    static let supportedVideoTypes: Set<String> = ["public.mpeg-4", "com.apple.quicktime-movie", "public.movie"]

    static func processImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let scaledTarget = CGSize(width: targetSize.width * UIScreen.main.scale,
                                  height: targetSize.height * UIScreen.main.scale)
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return image }

        let widthRatio = scaledTarget.width / imageSize.width
        let heightRatio = scaledTarget.height / imageSize.height
        let scale = max(widthRatio, heightRatio)

        let newSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (scaledTarget.width - newSize.width) / 2,
                             y: (scaledTarget.height - newSize.height) / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: scaledTarget, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: newSize))
        }
    }

    static func saveImage(_ image: UIImage, fileName: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return false }
        let url = BackgroundManager.backgroundsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func needsVideoConversion(asset: AVAsset) async -> Bool {
        guard let tracks = try? await asset.loadTracks(withMediaType: .video),
              let track = tracks.first else { return true }
        let formats = (try? await track.load(.formatDescriptions)) ?? []
        for format in formats {
            let codec = CMFormatDescriptionGetMediaSubType(format)
            if codec == kCMVideoCodecType_H264 || codec == kCMVideoCodecType_HEVC {
                return false
            }
        }
        return true
    }

    static func processVideo(sourceURL: URL, fileName: String) async -> Bool {
        let asset = AVURLAsset(url: sourceURL)
        let destination = BackgroundManager.backgroundsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destination)

        let needsConversion = await needsVideoConversion(asset: asset)
        if !needsConversion {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                return true
            } catch {
                return false
            }
        }

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return false
        }
        export.outputURL = destination
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        return await withCheckedContinuation { continuation in
            export.exportAsynchronously {
                continuation.resume(returning: export.status == .completed)
            }
        }
    }
}
