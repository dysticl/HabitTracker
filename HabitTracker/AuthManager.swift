//
//  AuthManager.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//
import Foundation
import AuthenticationServices
import Security

enum AuthError: Error, LocalizedError {
    case noCredentials
    case keychainError(String)
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "Keine Anmeldeinformationen verfügbar"
        case .keychainError(let message):
            return "Keychain-Fehler: \(message)"
        case .serverError(let message):
            return "Serverfehler: \(message)"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        }
    }
}

class AuthManager: NSObject, ASAuthorizationControllerDelegate {
    static let shared = AuthManager()
    private var completion: ((Result<String, Error>) -> Void)?
    private let baseURL = "https://api.davysgray.com"
    private let apiKey = "your-secret-api-key-1234567890"
    
    private override init() {}
    
    func signInWithApple(completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            self.completion?(.failure(AuthError.noCredentials))
            return
        }
        
        let appleId = appleIDCredential.user
        let name = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = appleIDCredential.email
        
        Task {
            do {
                let token = try await authenticateWithBackend(appleId: appleId, name: name, email: email)
                try saveToken(token)
                self.completion?(.success(token))
            } catch {
                self.completion?(.failure(error))
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        self.completion?(.failure(error))
    }
    
    private func authenticateWithBackend(appleId: String, name: String, email: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/apple") else {
            throw AuthError.serverError("Ungültige URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let body: [String: Any] = [
            "appleId": appleId,
            "name": name.isEmpty ? nil : name,
            "email": email.isEmpty ? nil : email
        ].compactMapValues { $0 }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.serverError("Authentifizierung fehlgeschlagen mit Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw AuthError.serverError("Ungültiges Token-Format")
        }
        
        return token
    }
    
    private func saveToken(_ token: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError("Fehler beim Speichern des Tokens: \(status)")
        }
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }
    
    func refreshToken() async throws -> String {
        guard let currentToken = getToken() else {
            throw AuthError.noCredentials
        }
        
        guard let url = URL(string: "\(baseURL)/auth/refresh") else {
            throw AuthError.serverError("Ungültige URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.serverError("Token-Refresh fehlgeschlagen mit Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["token"] as? String else {
            throw AuthError.serverError("Ungültiges Token-Format")
        }
        
        try saveToken(newToken)
        return newToken
    }
}
