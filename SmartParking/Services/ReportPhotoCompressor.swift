import Foundation
import UIKit
import os

struct CompressedReportPhoto: Sendable {
    let data: Data
    let originalBytes: Int
    let attempts: Int
    let elapsedMilliseconds: Double

    var compressedBytes: Int {
        data.count
    }

    var originalKB: Double {
        Double(originalBytes) / 1024
    }

    var compressedKB: Double {
        Double(compressedBytes) / 1024
    }
}

enum ReportPhotoError: LocalizedError {
    case invalidImage
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not read the photo."
        case .compressionFailed:
            return "Could not make the photo smaller."
        }
    }
}

enum ReportPhotoCompressor {

    static let maxBytes = 300 * 1024

    private static let qualities: [CGFloat] = [
        0.80,
        0.70,
        0.60,
        0.50
    ]

    private static let logger = Logger(
        subsystem: "com.andresmorales.SmartParking",
        category: "ReportPhotoCompression"
    )

    private static let signposter = OSSignposter(
        logger: logger
    )

    // MARK: - Background compression

    static func compress(
        _ originalData: Data
    ) async throws -> CompressedReportPhoto {

        let worker = Task.detached(
            priority: .userInitiated
        ) {
            try compressSynchronously(originalData)
        }

        return try await withTaskCancellationHandler(
            operation: {
                try await worker.value
            },
            onCancel: {
                worker.cancel()
            }
        )
    }

    // MARK: - Baseline implementation

    private static func compressSynchronously(
        _ originalData: Data
    ) throws -> CompressedReportPhoto {

        let interval = signposter.beginInterval("compress")

        defer {
            signposter.endInterval("compress", interval)
        }

        let startedAt = ProcessInfo.processInfo.systemUptime

        try Task.checkCancellation()

        guard let original = UIImage(data: originalData),
              original.size.width > 0,
              original.size.height > 0 else {
            throw ReportPhotoError.invalidImage
        }

        // Baseline: start at the original image resolution.
        var image = normalized(original)
        var attempts = 0

        while true {

            for quality in qualities {

                try Task.checkCancellation()

                attempts += 1

                guard let jpeg = image.jpegData(
                    compressionQuality: quality
                ) else {
                    continue
                }

                if jpeg.count <= maxBytes {

                    let elapsed = (
                        ProcessInfo.processInfo.systemUptime
                        - startedAt
                    ) * 1000

                    let result = CompressedReportPhoto(
                        data: jpeg,
                        originalBytes: originalData.count,
                        attempts: attempts,
                        elapsedMilliseconds: elapsed
                    )

                    logger.info(
                        "photo ready in \(Int(elapsed)) ms, \(attempts) attempts: \(Int(result.originalKB)) KB to \(Int(result.compressedKB)) KB"
                    )

                    return result
                }
            }

            let width = image.size.width * image.scale
            let height = image.size.height * image.scale

            guard width > 1 || height > 1 else {
                throw ReportPhotoError.compressionFailed
            }

            let smallerSize = CGSize(
                width: max(1, floor(width * 0.75)),
                height: max(1, floor(height * 0.75))
            )

            image = resized(image, to: smallerSize)
        }
    }

    // MARK: - Image orientation

    private static func normalized(
        _ image: UIImage
    ) -> UIImage {

        if image.imageOrientation == .up,
           image.scale == 1 {
            return image
        }

        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )

        return resized(image, to: pixelSize)
    }

    // MARK: - Image resizing

    private static func resized(
        _ image: UIImage,
        to size: CGSize
    ) -> UIImage {

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: size,
            format: format
        )

        return renderer.image { _ in
            image.draw(
                in: CGRect(
                    origin: .zero,
                    size: size
                )
            )
        }
    }
}