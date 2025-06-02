import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HabitViewModel()
    @State private var isLoggedIn = false
    
    var body: some View {
        if isLoggedIn {
            DashboardView(isLoggedIn: $isLoggedIn, viewModel: viewModel)
        } else {
            LoginView(isLoggedIn: $isLoggedIn, viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
