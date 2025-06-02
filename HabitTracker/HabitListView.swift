//
//  HabitListView.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//
import SwiftUI

struct HabitListView: View {
    @ObservedObject var viewModel: HabitViewModel
    @Binding var proofHabitId: UUID?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 60)
                
                VStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if viewModel.habits.isEmpty {
                        Text("Keine Habits vorhanden. Füge ein Habit hinzu!")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        ForEach($viewModel.habits) { $habit in
                            HabitRow(habit: $habit, viewModel: viewModel, onProofRequest: {
                                proofHabitId = habit.id
                            })
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .slide.combined(with: .opacity)))
                        }
                    }
                    
                    if viewModel.isAdding {
                        VStack(spacing: 8) {
                            TextField("Habit Name", text: $viewModel.newHabitName)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            TextField("Deadline (Stunden, optional)", text: $viewModel.newHabitDeadlineHours)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .keyboardType(.numberPad)
                            
                            Button(action: {
                                viewModel.addHabit()
                            }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                                    .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        Button(action: {
                            withAnimation {
                                viewModel.isAdding = true
                                viewModel.errorMessage = nil
                            }
                        }) {
                            HStack {
                                Text("Add Habit")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                Spacer()
                            }
                            .padding()
                            .background(.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                Spacer()
                    .frame(height: 200)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: Binding(
            get: { proofHabitId != nil },
            set: { if !$0 { proofHabitId = nil } }
        )) {
            if let habitId = proofHabitId, let habit = viewModel.habits.first(where: { $0.id == habitId }) {
                ProofPopup(habit: habit, onUpload: { photoData in
                    Task {
                        await viewModel.uploadProof(for: habit, photoData: photoData)
                        proofHabitId = nil
                    }
                })
            }
        }
    }
}

#Preview {
    HabitListView(viewModel: HabitViewModel(), proofHabitId: .constant(nil))
}
