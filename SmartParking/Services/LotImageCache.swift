import CryptoKit
import Foundation
import UIKit

protocol LotImageCaching: Sendable {
    func image(for url: URL) async -> UIImage?
}

actor LotImageCache: LotImageCaching {
    static let shared = LotImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let directory: URL
    private let session: URLSession
    private let diskLimit: Int
    private var downloads: [URL: Task<UIImage?, Never>] = [:]

    init(
        directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "LotImages"),
        session: URLSession = .shared,
        memoryCountLimit: Int = 40,
        memoryCostLimit: Int = 40 * 1024 * 1024,
        diskLimit: Int = 50 * 1024 * 1024
    ) {
        self.directory = directory
        self.session = session
        self.diskLimit = diskLimit
        memory.countLimit = memoryCountLimit
        memory.totalCostLimit = memoryCostLimit
    }

    func image(for url: URL) async -> UIImage? {
        if let image = memory.object(forKey: url as NSURL) {
            return image
        }
        if let download = downloads[url] {
            return await download.value
        }
        let download = Task { await load(url) }
        downloads[url] = download
        let image = await download.value
        downloads[url] = nil
        return image
    }

    private func load(_ url: URL) async -> UIImage? {
        let file = fileURL(for: url)
        let saved = await Task.detached(priority: .utility) {
            Self.decodedImage(contentsOf: file)
        }.value
        if let saved {
            remember(saved, for: url)
            return saved
        }

        guard
            let result = try? await session.data(from: url),
            let status = (result.1 as? HTTPURLResponse)?.statusCode,
            (200..<300).contains(status)
        else { return nil }

        let data = result.0
        let downloaded = await Task.detached(priority: .utility) {
            Self.decodedImage(from: data)
        }.value
        guard let downloaded else { return nil }

        remember(downloaded, for: url)
        let directory = directory
        let diskLimit = diskLimit
        Task.detached(priority: .utility) {
            Self.write(data, to: file, in: directory, limit: diskLimit)
        }
        return downloaded
    }

    private func remember(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        memory.setObject(image, forKey: url as NSURL, cost: cost)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: name)
    }

    private static func decodedImage(contentsOf file: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return decodedImage(from: data)
    }

    private static func decodedImage(from data: Data) -> UIImage? {
        UIImage(data: data)?.preparingForDisplay()
    }

    private static func write(_ data: Data, to file: URL, in directory: URL, limit: Int) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        trim(directory, to: limit)
    }

    private static func trim(_ directory: URL, to limit: Int) {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys)
        ) else { return }

        let entries = files
            .compactMap { file -> (url: URL, date: Date, size: Int)? in
                guard
                    let values = try? file.resourceValues(forKeys: keys),
                    let date = values.contentModificationDate,
                    let size = values.fileSize
                else { return nil }
                return (file, date, size)
            }
            .sorted { $0.date < $1.date }

        var total = entries.reduce(0) { $0 + $1.size }
        for entry in entries where total > limit {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}
