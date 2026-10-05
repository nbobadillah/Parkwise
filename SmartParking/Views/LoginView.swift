import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AuthHeader(
                        title: "Welcome back",
                        subtitle: "Sign in to reserve a spot and find your car."
                    )

                    VStack(spacing: 16) {
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
                            contentType: .password
                        )
                    }

                    if let message = viewModel.errorMessage {
                        AuthBanner(message: message, isError: true)
                    }

                    PrimaryButton(
                        title: "Sign in",
                        isLoading: viewModel.isLoading,
                        isEnabled: viewModel.canSignIn
                    ) {
                        Task { await viewModel.signIn() }
                    }

                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(Palette.muted)
                        Button("Create one") {
                            viewModel.clearMessages()
                            showRegister = true
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.accent)
                    }
                    .font(.system(size: 14))
                }
                .padding(24)
                .padding(.top, 32)
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
