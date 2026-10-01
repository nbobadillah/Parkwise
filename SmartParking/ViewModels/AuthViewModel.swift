import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var isLoading = false
    @Published private(set) var isRestoring = true
    @Published var errorMessage: String?

    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""

    private let service: AuthServicing

    init(service: AuthServicing) {
        self.service = service
    }

    var isAuthenticated: Bool { user != nil }

    var canSignIn: Bool {
        isValidEmail(trimmedEmail) && !password.isEmpty && !isLoading
    }

    var canRegister: Bool {
        !trimmedName.isEmpty
            && isValidEmail(trimmedEmail)
            && password.count >= 6
            && password == confirmPassword
            && !isLoading
    }

    var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    func signIn() async {
        guard canSignIn else { return }
        await perform {
            self.user = try await self.service.signIn(email: self.trimmedEmail, password: self.password)
            self.clearForm()
        }
    }

    func register() async {
        guard canRegister else { return }
        await perform {
            self.user = try await self.service.register(
                name: self.trimmedName,
                email: self.trimmedEmail,
                password: self.password
            )
            self.clearForm()
        }
    }

    func restoreSession() async {
        user = await service.restoreSession()
        isRestoring = false
    }

    func signOut() {
        service.signOut()
        user = nil
        clearForm()
    }

    func clearMessages() {
        errorMessage = nil
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    private func clearForm() {
        name = ""
        email = ""
        password = ""
        confirmPassword = ""
    }

    private func perform(_ action: () async throws -> Void) async {
        isLoading = true
        clearMessages()
        defer { isLoading = false }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
