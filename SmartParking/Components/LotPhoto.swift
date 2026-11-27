import SwiftUI

struct LotPhoto: View {
    @StateObject private var viewModel: LotPhotoViewModel

    init(url: URL?) {
        _viewModel = StateObject(wrappedValue: LotPhotoViewModel(url: url))
    }

    var body: some View {
        if let image = viewModel.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
