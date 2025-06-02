//
//  TabBarView.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//
import SwiftUI

struct TabBarView: View {
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        HStack {
            TabBarItem(icon: "flame", label: "Habits")
            TabBarItem(icon: "flag", label: "Ziele")
            TabBarItem(icon: "person.3", label: "Freunde")
            TabBarItem(icon: "gear", label: "Einstellungen")
                .onTapGesture {
                    // Einfaches Logout für Demo
                    AuthManager.shared.clearToken()
                    isLoggedIn = false
                }
        }
        .padding(.bottom, 16)
    }
}

#Preview {
    TabBarView(isLoggedIn: .constant(true))
}
