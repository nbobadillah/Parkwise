import SwiftUI

struct AuthHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "parkingsign")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.accent)
                )
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AuthField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var hasError = false

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 20)
                input
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.ink)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(isSecure || keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled()
                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(hasError ? Palette.redInk : Palette.line, lineWidth: hasError ? 1.6 : 1)
            )
        }
    }

    @ViewBuilder
    private var input: some View {
        if isSecure && !isRevealed {
            SecureField("", text: $text)
        } else {
            TextField("", text: $text)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? Palette.accent : Palette.slate)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

struct AuthBanner: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(isError ? Palette.redInk : Palette.greenInk)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isError ? Palette.redSoft : Palette.greenSoft)
        )
    }
}
