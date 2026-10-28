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
                        contentType: .name,
                        hasError: viewModel.nameError != nil,
                        sanitize: { old, new in viewModel.acceptName(new, previous: old) }
                    )
                    if let nameError = viewModel.nameError {
                        fieldMessage(nameError, isError: true)
                    }
                    AuthField(
                        title: "Email",
                        icon: "envelope",
                        text: $viewModel.email,
                        keyboard: .emailAddress,
                        contentType: .emailAddress,
                        hasError: viewModel.registerEmailError != nil,
                        sanitize: { _, new in AuthValidation.cleanEmail(new) }
                    )
                    if let emailError = viewModel.registerEmailError {
                        fieldMessage(emailError, isError: true)
                    }
                    if !viewModel.emailSuggestions.isEmpty {
                        emailSuggestions
                    }
                    AuthField(
                        title: "Password",
                        icon: "lock",
                        text: $viewModel.password,
                        isSecure: true,
                        contentType: .newPassword,
                        sanitize: { _, new in AuthValidation.cleanPassword(new) }
                    )
                    passwordChecklist
                    AuthField(
                        title: "Confirm password",
                        icon: "lock.rotation",
                        text: $viewModel.confirmPassword,
                        isSecure: true,
                        contentType: .newPassword,
                        hasError: viewModel.passwordMismatch,
                        sanitize: { _, new in AuthValidation.cleanPassword(new) }
                    )
                    if viewModel.passwordMismatch {
                        fieldMessage("Passwords don't match.", isError: true)
                    }
                }

                if let message = viewModel.offlineMessage {
                    AuthBanner(message: message, isError: true)
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
        .onAppear { viewModel.restoreDraft() }
        .onDisappear { viewModel.discardRegisterForm() }
    }

    private func fieldMessage(_ message: String, isError: Bool) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(isError ? Palette.redInk : Palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emailSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.emailSuggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.email = suggestion
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(Palette.accentSoft)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var passwordChecklist: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.passwordRules) { rule in
                Label(rule.title, systemImage: rule.isMet ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(rule.isMet ? Palette.greenInk : Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
