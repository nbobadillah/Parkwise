import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            if let user = viewModel.user {
                VStack(spacing: 12) {
                    Text(user.initials)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Palette.accentSoft))
                    Text(user.displayName.isEmpty ? "Parkwise user" : user.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(user.email)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .cardStyle()
            }

            if let message = viewModel.errorMessage {
                AuthBanner(message: message, isError: true)
            }

            Button(role: .destructive) {
                viewModel.signOut()
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.redInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.redSoft)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.screen)
    }
}
