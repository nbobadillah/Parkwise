import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AuthHeader(
                        title: "Log in",
                        subtitle: "Use your account to find and reserve a spot."
                    )

                    if viewModel.offlineMessage != nil {
                        NoticeBox(
                            message: "Logging in needs a connection. What you type stays here and the button turns on as soon as the phone is back online. You can keep browsing with 'Not now'.",
                            title: "You're offline",
                            icon: "icloud.slash"
                        )
                        .padding(.top, 24)
                    }

                    if let message = viewModel.errorMessage {
                        AuthBanner(message: message, isError: true)
                            .padding(.top, 16)
                    }

                    VStack(spacing: 16) {
                        AuthField(
                            title: "Email",
                            icon: "envelope",
                            text: $viewModel.email,
                            keyboard: .emailAddress,
                            contentType: .emailAddress,
                            sanitize: { _, new in AuthValidation.cleanEmail(new) }
                        )
                        AuthField(
                            title: "Password",
                            icon: "lock",
                            text: $viewModel.password,
                            isSecure: true,
                            contentType: .password,
                            sanitize: { _, new in AuthValidation.cleanPassword(new) }
                        )
                    }
                    .padding(.top, 24)

                    PrimaryButton(
                        title: viewModel.isConnected ? "Log in" : "Waiting for connection",
                        isLoading: viewModel.isLoading,
                        isEnabled: viewModel.canSignIn
                    ) {
                        Task { await viewModel.signIn() }
                    }
                    .padding(.top, 24)

                    SecondaryButton(title: "Create an account", isEnabled: !viewModel.isLoading) {
                        viewModel.clearMessages()
                        showRegister = true
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 16)
                .padding(.top, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.screen)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        viewModel.clearMessages()
                        dismiss()
                    }
                    .foregroundStyle(Palette.accent)
                }
            }
        }
    }
}
