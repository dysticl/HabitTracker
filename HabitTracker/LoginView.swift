//
//  LoginView.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//
import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @ObservedObject var viewModel: HabitViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var name: String = ""
    @State private var loginError: String?
    @State private var isSigningUp: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Willkommen bei Habit Tracker")
                .font(.title)
                .foregroundColor(.white)
                .padding()
            
            Text(isSigningUp ? "Registrieren" : "Anmelden")
                .font(.title2)
                .foregroundColor(.white)
                .padding()
            
            if isSigningUp {
                TextField("Name (optional)", text: $name)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding()
                    .background(.white.opacity(0.1))
                    .cornerRadius(8)
                    .autocapitalization(.none)
            }
            
            TextField("E-Mail", text: $email)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .padding()
                .background(.white.opacity(0.1))
                .cornerRadius(8)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            SecureField("Passwort", text: $password)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .padding()
                .background(.white.opacity(0.1))
                .cornerRadius(8)
            
            Button(action: {
                Task {
                    do {
                        if isSigningUp {
                            try await AuthManager.shared.signUp(email: email, password: password, name: name.isEmpty ? nil : name)
                        } else {
                            try await AuthManager.shared.signIn(email: email, password: password)
                        }
                        DispatchQueue.main.async {
                            isLoggedIn = true
                            Task {
                                await viewModel.fetchHabits()
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            loginError = error.localizedDescription
                        }
                    }
                }
            }) {
                Text(isSigningUp ? "Registrieren" : "Anmelden")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isSigningUp ? .green : .blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Button(action: {
                isSigningUp.toggle()
                loginError = nil
                email = ""
                password = ""
                name = ""
            }) {
                Text(isSigningUp ? "Stattdessen anmelden?" : "Stattdessen registrieren?")
                    .foregroundColor(.blue)
                    .padding()
            }
            
            if let loginError = loginError {
                Text(loginError)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .background(
            BlurView(style: .systemUltraThinMaterialDark)
                .ignoresSafeArea()
        )
        .onAppear {
            if AuthManager.shared.getToken() != nil {
                isLoggedIn = true
                Task {
                    await viewModel.fetchHabits()
                }
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false), viewModel: HabitViewModel())
}
