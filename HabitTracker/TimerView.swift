//
//  TimerView.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//
import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: HabitViewModel
    @State private var timeRemaining: Int = 3600
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var timeRemainingFormatted: String {
        let hours = timeRemaining / 3600
        let minutes = (timeRemaining % 3600) / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private var activeHabitWithDeadline: Habit? {
        viewModel.habits.first { habit in
            !habit.isCompleted && habit.deadlineDuration != nil
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if let activeHabit = activeHabitWithDeadline {
                Text(activeHabit.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            } else {
                Text("Kein aktives Habit")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(timeRemainingFormatted)
                .monospacedDigit()
                .foregroundColor(timeRemaining <= 300 ? .red : .white)
                .font(.system(size: 32, weight: .bold))
                .onReceive(timer) { _ in
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    }
                    if timeRemaining <= 0 {
                        updateTimer()
                    }
                }
        }
        .padding(.bottom, 8)
        .onChange(of: viewModel.habits) { _ in
            updateTimer()
        }
    }
    
    private func updateTimer() {
        if let activeHabit = activeHabitWithDeadline,
           let deadline = activeHabit.deadlineDuration {
            timeRemaining = max(0, deadline)
        } else {
            timeRemaining = 3600
        }
    }
}

#Preview {
    TimerView(viewModel: HabitViewModel())
}
