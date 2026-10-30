import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AuthHeader(
                    title: "Create account",
                    subtitle: "Your reservations sync with the Android app too."
                )

                if viewModel.offlineMessage != nil {
                    NoticeBox(
                        message: "Creating an account needs a connection. Your name and email are saved on this phone, so you can finish when the connection is back.",
                        title: "You're offline",
                        icon: "icloud.slash"
                    )
                    .padding(.top, 24)
                } else if viewModel.restoredDraft {
                    NoticeBox(
                        message: "We filled in the name and email you started before. Choose a password to finish.",
                        icon: "arrow.counterclockwise"
                    )
                    .padding(.top, 24)
                }

                if let message = viewModel.errorMessage {
                    AuthBanner(message: message, isError: true)
                        .padding(.top, 16)
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        AuthField(
                            title: "Name",
                            icon: "person",
                            text: $viewModel.name,
                            contentType: .name,
                            hasError: viewModel.nameError != nil,
                            sanitize: { old, new in viewModel.acceptName(new, previous: old) }
                        )
                        if let nameError = viewModel.nameError {
                            fieldMessage(nameError, isError: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
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
                        } else {
                            fieldMessage("Gmail, Outlook, Hotmail, Live, Yahoo, iCloud, Proton or Uniandes", isError: false)
                        }
                        if !viewModel.emailSuggestions.isEmpty {
                            emailSuggestions
                                .padding(.top, 4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        AuthField(
                            title: "Password",
                            icon: "lock",
                            text: $viewModel.password,
                            isSecure: true,
                            contentType: .newPassword,
                            sanitize: { _, new in AuthValidation.cleanPassword(new) }
                        )
                        passwordChecklist
                            .padding(.horizontal, 12)
                    }
                    VStack(alignment: .leading, spacing: 4) {
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
                            fieldMessage("Passwords don't match", isError: true)
                        }
                    }
                }
                .padding(.top, 24)

                PrimaryButton(
                    title: viewModel.isConnected ? "Create account" : "Waiting for connection",
                    isLoading: viewModel.isLoading,
                    isEnabled: viewModel.canRegister
                ) {
                    Task { await viewModel.register() }
                }
                .padding(.top, 24)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.screen)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.restoreDraft() }
        .onDisappear { viewModel.discardRegisterForm() }
    }

    private func fieldMessage(_ message: String, isError: Bool) -> some View {
        Text(message)
            .font(AppFont.caption)
            .foregroundStyle(isError ? Palette.redInk : Palette.muted)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emailSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.emailSuggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.email = suggestion
                    } label: {
                        Text(suggestion)
                            .font(AppFont.button)
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .fill(Palette.accentSoft)
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
                    .font(AppFont.caption)
                    .foregroundStyle(rule.isMet ? Palette.greenInk : Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
