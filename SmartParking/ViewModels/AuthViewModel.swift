import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var isLoading = false
    @Published private(set) var isRestoring = true
    @Published var errorMessage: String?
    @Published private(set) var isConnected = true

    @Published private(set) var nameError: String?
    @Published private(set) var restoredDraft = false

    @Published var name = "" {
        didSet { saveDraft(name, forKey: Self.draftNameKey) }
    }
    @Published var email = "" {
        didSet { saveDraft(email, forKey: Self.draftEmailKey) }
    }
    @Published var password = ""
    @Published var confirmPassword = ""

    private static let draftNameKey = "registerDraftName"
    private static let draftEmailKey = "registerDraftEmail"

    private let service: AuthServicing
    private let defaults: UserDefaults
    private var sessionExpiredObserver: NSObjectProtocol?
    private var isClearingForm = false
    private var nameRevertedTo: String?

    init(service: AuthServicing, networkMonitor: NetworkMonitor = .shared, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        isConnected = networkMonitor.isConnected
        networkMonitor.$isConnected.assign(to: &$isConnected)
        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.signOut()
            }
        }
    }

    deinit {
        if let sessionExpiredObserver {
            NotificationCenter.default.removeObserver(sessionExpiredObserver)
        }
    }

    var isAuthenticated: Bool { user != nil }

    var canSignIn: Bool {
        AuthValidation.isValidEmailFormat(trimmedEmail) && !password.isEmpty && !isLoading && isConnected
    }

    var canRegister: Bool {
        AuthValidation.isValidName(trimmedName)
            && AuthValidation.isValidEmailFormat(trimmedEmail)
            && AuthValidation.isRealProvider(trimmedEmail)
            && AuthValidation.isStrongPassword(password)
            && password == confirmPassword
            && !isLoading
            && isConnected
    }

    func acceptName(_ new: String, previous: String) -> String {
        if new == nameRevertedTo {
            nameRevertedTo = nil
            return new
        }
        if new.count > AuthValidation.maxNameLength {
            let limited = String(new.prefix(AuthValidation.maxNameLength))
            nameError = AuthValidation.nameRejection(new)
            nameRevertedTo = AuthValidation.nameRejection(limited) == nil ? limited : previous
            return nameRevertedTo ?? previous
        }
        if let rejection = AuthValidation.nameRejection(new) {
            nameError = rejection
            nameRevertedTo = previous
            return previous
        }
        nameError = nil
        return new
    }

    var registerEmailError: String? {
        AuthValidation.emailError(trimmedEmail)
    }

    var emailSuggestions: [String] {
        AuthValidation.emailSuggestions(trimmedEmail)
    }

    var passwordRules: [PasswordRule] {
        AuthValidation.passwordRules(password)
    }

    var offlineMessage: String? {
        isConnected ? nil : "Signing in needs a connection. You can keep browsing with 'Not now'."
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
            self.clearDraft()
        }
    }

    func discardRegisterForm() {
        clearForm()
        clearDraft()
        clearMessages()
        nameRevertedTo = nil
        restoredDraft = false
    }

    func restoreDraft() {
        let savedName = defaults.string(forKey: Self.draftNameKey) ?? ""
        let savedEmail = defaults.string(forKey: Self.draftEmailKey) ?? ""
        restoredDraft = (name.isEmpty && !savedName.isEmpty) || (email.isEmpty && !savedEmail.isEmpty)
        if name.isEmpty {
            name = savedName
        }
        if email.isEmpty {
            email = savedEmail
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
        nameError = nil
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func clearForm() {
        isClearingForm = true
        defer { isClearingForm = false }
        name = ""
        email = ""
        password = ""
        confirmPassword = ""
    }

    private func saveDraft(_ value: String, forKey key: String) {
        guard !isClearingForm else { return }
        defaults.set(value, forKey: key)
    }

    private func clearDraft() {
        defaults.removeObject(forKey: Self.draftNameKey)
        defaults.removeObject(forKey: Self.draftEmailKey)
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
