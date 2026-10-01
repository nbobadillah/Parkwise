import Foundation

protocol AuthServicing: AnyObject {
    var token: String? { get }
    func restoreSession() async -> AppUser?
    func signIn(email: String, password: String) async throws -> AppUser
    func register(name: String, email: String, password: String) async throws -> AppUser
    func signOut()
}

enum AuthServiceError: LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case invalidInput
    case network
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Incorrect email or password."
        case .emailAlreadyInUse: return "An account with this email already exists."
        case .invalidInput: return "Check the email and use a password with at least 6 characters."
        case .network: return "Could not reach the Parkwise server. Check your connection."
        case .unknown(let message): return message
        }
    }
}

final class BackendAuthService: AuthServicing {
    private struct Credentials: Encodable {
        let name: String?
        let email: String
        let password: String
    }

    private struct UserResponse: Decodable {
        let id: String
        let email: String
        let name: String?
    }

    private struct SessionResponse: Decodable {
        let token: String
        let user: UserResponse
    }

    private let client: APIClient
    private let store: SessionStoring
    private(set) var token: String?

    init(client: APIClient = .shared, store: SessionStoring = KeychainSessionStore()) {
        self.client = client
        self.store = store
    }

    func restoreSession() async -> AppUser? {
        guard let saved = store.load() else { return nil }
        do {
            let response: UserResponse = try await client.send("GET", "/api/v1/auth/me", token: saved.token)
            let user = Self.makeAppUser(from: response)
            store.save(token: saved.token, user: user)
            token = saved.token
            return user
        } catch APIError.server(let status, _) where status == 401 {
            signOut()
            return nil
        } catch {
            token = saved.token
            return saved.user
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try await authenticate(path: "/api/v1/auth/login", credentials: Credentials(name: nil, email: email, password: password))
    }

    func register(name: String, email: String, password: String) async throws -> AppUser {
        try await authenticate(path: "/api/v1/auth/register", credentials: Credentials(name: name, email: email, password: password))
    }

    func signOut() {
        token = nil
        store.clear()
    }

    private func authenticate(path: String, credentials: Credentials) async throws -> AppUser {
        do {
            let session: SessionResponse = try await client.send("POST", path, body: credentials)
            let user = Self.makeAppUser(from: session.user)
            store.save(token: session.token, user: user)
            token = session.token
            return user
        } catch {
            throw Self.map(error)
        }
    }

    private static func makeAppUser(from response: UserResponse) -> AppUser {
        AppUser(id: response.id, email: response.email, displayName: response.name ?? "")
    }

    private static func map(_ error: Error) -> AuthServiceError {
        switch error {
        case APIError.network:
            return .network
        case APIError.server(401, _):
            return .invalidCredentials
        case APIError.server(409, _):
            return .emailAlreadyInUse
        case APIError.server(400, _):
            return .invalidInput
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
