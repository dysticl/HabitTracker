//
//  DashboardView.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//
import SwiftUI

struct DashboardView: View {
    @Binding var isLoggedIn: Bool
    @StateObject var viewModel: HabitViewModel
    @State private var proofHabitId: UUID?
    
    var body: some View {
        ZStack {
            BlurView(style: .systemUltraThinMaterialDark)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HeaderView()
                
                TimerView(viewModel: viewModel)
                
                HabitListView(viewModel: viewModel, proofHabitId: $proofHabitId)
                
                ChartView(viewModel: viewModel)
                
                TabBarView(isLoggedIn: $isLoggedIn)
            }
            .ignoresSafeArea(.bottom)
            .alert(isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(viewModel.errorMessage ?? "Unbekannter Fehler"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

#Preview {
    DashboardView(isLoggedIn: .constant(true), viewModel: HabitViewModel())
}
