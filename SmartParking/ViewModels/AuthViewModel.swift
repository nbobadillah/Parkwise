import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var isLoading = false
    @Published private(set) var isRestoring = true
    @Published var errorMessage: String?
    @Published private(set) var isConnected = true

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

    init(service: AuthServicing, networkMonitor: NetworkMonitor = .shared, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        name = defaults.string(forKey: Self.draftNameKey) ?? ""
        email = defaults.string(forKey: Self.draftEmailKey) ?? ""
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
        isValidEmail(trimmedEmail) && !password.isEmpty && !isLoading && isConnected
    }

    var canRegister: Bool {
        !trimmedName.isEmpty
            && isValidEmail(trimmedEmail)
            && password.count >= 6
            && password == confirmPassword
            && !isLoading
            && isConnected
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

    func restoreDraft() {
        if name.isEmpty {
            name = defaults.string(forKey: Self.draftNameKey) ?? ""
        }
        if email.isEmpty {
            email = defaults.string(forKey: Self.draftEmailKey) ?? ""
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
