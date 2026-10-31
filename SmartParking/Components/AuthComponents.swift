import SwiftUI

struct AuthBrand: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("P")
                .font(AppFont.heading1)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Palette.accent)
                )
            Text("ParkWise")
                .font(AppFont.heading1)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
    }
}

struct AuthHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuthBrand()
            Text(title)
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)
                .padding(.top, 32)
            Text(subtitle)
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
                .padding(.top, 4)
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
    var helper: String?
    var sanitize: ((_ old: String, _ new: String) -> String)?

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Text(title)
                        .font(isFloating ? AppFont.caption : AppFont.body)
                        .foregroundStyle(labelColor)
                        .offset(y: isFloating ? -11 : 0)
                    input
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ink)
                        .keyboardType(keyboard)
                        .textContentType(contentType)
                        .textInputAutocapitalization(isSecure || keyboard == .emailAddress ? .never : .words)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .offset(y: 8)
                }
                .animation(.easeOut(duration: 0.15), value: isFloating)
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
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.neutral)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused || hasError ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }

            if let helper {
                Text(helper)
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
                    .padding(.horizontal, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: text) { old, new in
            guard let sanitize else { return }
            let accepted = sanitize(old, new)
            if accepted != new {
                text = accepted
            }
        }
    }

    private var isFloating: Bool {
        isFocused || !text.isEmpty
    }

    private var labelColor: Color {
        if hasError { return Palette.redInk }
        return isFocused ? Palette.accent : Palette.muted
    }

    private var borderColor: Color {
        if hasError { return Palette.redInk }
        return isFocused ? Palette.accent : Palette.line
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
                        .font(AppFont.button)
                }
            }
            .foregroundStyle(isEnabled ? .white : Palette.ink.opacity(0.38))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(isEnabled ? Palette.accent : Palette.ink.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.button)
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .stroke(Palette.accent, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

struct AuthBanner: View {
    let message: String
    let isError: Bool

    var body: some View {
        NoticeBox(
            message: message,
            tone: isError ? .danger : .warning,
            icon: isError ? "exclamationmark.circle" : "checkmark.circle"
        )
    }
}
