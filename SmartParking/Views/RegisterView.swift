import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AuthHeader(
                    title: "Create account",
                    subtitle: "Register with your email to start using Parkwise."
                )

                VStack(spacing: 16) {
                    AuthField(
                        title: "Full name",
                        icon: "person",
                        text: $viewModel.name,
                        contentType: .name
                    )
                    AuthField(
                        title: "Email",
                        icon: "envelope",
                        text: $viewModel.email,
                        keyboard: .emailAddress,
                        contentType: .emailAddress
                    )
                    AuthField(
                        title: "Password",
                        icon: "lock",
                        text: $viewModel.password,
                        isSecure: true,
                        contentType: .newPassword
                    )
                    AuthField(
                        title: "Confirm password",
                        icon: "lock.rotation",
                        text: $viewModel.confirmPassword,
                        isSecure: true,
                        contentType: .newPassword,
                        hasError: viewModel.passwordMismatch
                    )
                    Text(viewModel.passwordMismatch ? "Passwords don't match." : "At least 6 characters.")
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.passwordMismatch ? Palette.redInk : Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let message = viewModel.errorMessage {
                    AuthBanner(message: message, isError: true)
                }

                PrimaryButton(
                    title: "Create account",
                    isLoading: viewModel.isLoading,
                    isEnabled: viewModel.canRegister
                ) {
                    Task { await viewModel.register() }
                }

                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(Palette.muted)
                    Button("Sign in") {
                        viewModel.clearMessages()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.accent)
                }
                .font(.system(size: 14))
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.screen)
        .navigationBarTitleDisplayMode(.inline)
    }
}
