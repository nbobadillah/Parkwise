import UIKit

@MainActor
final class LotPhotoViewModel: ObservableObject {
    @Published private(set) var image: UIImage?

    init(url: URL?, cache: LotImageCaching = LotImageCache.shared) {
        guard let url else { return }
        Task { [weak self] in
            let image = await cache.image(for: url)
            self?.image = image
        }
    }
}
