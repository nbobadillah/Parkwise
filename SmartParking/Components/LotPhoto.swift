import SwiftUI

struct LotPhoto: View {
    @StateObject private var viewModel: LotPhotoViewModel

    private let width: CGFloat?
    private let height: CGFloat

    init(url: URL?, cache: LotImageCaching = LotImageCache.shared, width: CGFloat? = nil, height: CGFloat = 140) {
        _viewModel = StateObject(wrappedValue: LotPhotoViewModel(url: url, cache: cache))
        self.width = width
        self.height = height
    }

    var body: some View {
        if let image = viewModel.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .frame(maxWidth: width == nil ? .infinity : width)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
