import SwiftUI
import Charts
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = HabitViewModel()
    @State private var timeRemaining: Int = 3600
    @State private var currentStreak: Int = 3
    @State private var xpValues: [Int] = [10, 20, 5, 30, 15, 25, 18]
    @State private var xpDays: [String] = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    @State private var proofHabitId: UUID?
    @State private var isLoggedIn = false
    @State private var loginError: String?
    @State private var email: String = ""
    @State private var password: String = ""
    
    private var timeRemainingFormatted: String {
        let hours = timeRemaining / 3600
        let minutes = (timeRemaining % 3600) / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private var activeHabitWithDeadline: Habit? {
        return viewModel.habits.first { habit in
            !habit.isCompleted && habit.deadlineDuration != nil
        }
    }
    
    private var categories: [(name: String, emoji: String, progress: Double)] {
        let grouped = Dictionary(grouping: viewModel.habits) { $0.category }
        return grouped.map { category, habits in
            let averageProgress = habits.map { $0.progress }.reduce(0, +) / Double(max(1, habits.count))
            return (name: category, emoji: habits.first?.emoji ?? "⭐️", progress: averageProgress)
        }.sorted { $0.name < $1.name }
    }
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        if isLoggedIn {
            ZStack {
                BlurView(style: .systemUltraThinMaterialDark)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(Text("D").foregroundColor(.white))
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("LVL 1.")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            ProgressView(value: 0.2)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                .frame(width: 100)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("\(currentStreak)")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .font(.system(size: 26))
                                .shadow(color: .orange.opacity(0.5), radius: 2)
                                .shadow(color: .orange.opacity(0.3), radius: 4)
                            
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .shadow(color: .orange.opacity(0.5), radius: 2)
                                .shadow(color: .orange.opacity(0.3), radius: 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    HStack(spacing: 12) {
                        ForEach(0..<5) { index in
                            ZStack {
                                Circle()
                                    .fill(index < currentStreak ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "flame.fill")
                                    .foregroundColor(index < currentStreak ? .orange : .gray)
                                    .scaleEffect(0.9)
                                    .shadow(color: .orange.opacity(0.5), radius: 2)
                                    .shadow(color: .orange.opacity(0.3), radius: 4)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                        .padding(.bottom, 8)
                    
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
                                    updateTimerForActiveHabit()
                                }
                            }
                    }
                    .padding(.bottom, 8)
                    
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
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .foregroundColor(.white)
                                            .padding(.horizontal)
                                        
                                        TextField("Deadline (Stunden, optional)", text: $viewModel.newHabitDeadlineHours)
                                            .textFieldStyle(PlainTextFieldStyle())
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
                    
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("XP")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Chart {
                                ForEach(0..<xpValues.count, id: \.self) { index in
                                    LineMark(
                                        x: .value("Tag", xpDays[index]),
                                        y: .value("XP", xpValues[index])
                                    )
                                    .foregroundStyle(Color.green)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                    
                                    PointMark(
                                        x: .value("Tag", xpDays[index]),
                                        y: .value("XP", xpValues[index])
                                    )
                                    .foregroundStyle(Color.green)
                                    .symbolSize(30)
                                }
                            }
                            .chartYAxis(.hidden)
                            .chartXAxis {
                                AxisMarks(preset: .aligned, position: .bottom) { _ in
                                    AxisValueLabel()
                                        .foregroundStyle(Color.white.opacity(0.6))
                                        .font(.caption2)
                                }
                            }
                            .frame(height: 60)
                            .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 8) {
                            ForEach(categories, id: \.name) { category in
                                HStack {
                                    Text(category.emoji)
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(.white.opacity(0.1))
                                                .frame(height: 12)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(.green)
                                                .frame(width: geometry.size.width * max(0.0, min(1.0, category.progress)), height: 12)
                                        }
                                    }
                                    .frame(height: 12)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                        .padding(.bottom, 8)
                    
                    HStack {
                        TabBarItem(icon: "flame", label: "Habits")
                        TabBarItem(icon: "flag", label: "Ziele")
                        TabBarItem(icon: "person.3", label: "Freunde")
                        TabBarItem(icon: "gear", label: "Einstellungen")
                    }
                    .padding(.bottom, 16)
                }
                .ignoresSafeArea(.bottom)
                .onChange(of: viewModel.habits) { _ in
                    updateTimerForActiveHabit()
                }
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
        } else {
            VStack(spacing: 20) {
                Text("Willkommen bei Habit Tracker")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                
                Text("Bitte anmelden")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                
                TextField("E-Mail", text: $email)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .padding()
                    .background(.white.opacity(0.1))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                SecureField("Passwort", text: $password)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .padding()
                    .background(.white.opacity(0.1))
                    .cornerRadius(8)
                
                Button(action: {
                    Task {
                        do {
                            try await AuthManager.shared.signIn(email: email, password: password)
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
                    Text("Anmelden")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
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
    
    private func updateTimerForActiveHabit() {
        if let activeHabit = activeHabitWithDeadline,
           let deadline = activeHabit.deadlineDuration {
            timeRemaining = max(0, deadline)
        } else {
            timeRemaining = 3600
        }
    }
}

struct HabitRow: View {
    @Binding var habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    let onProofRequest: () -> Void
    
    var body: some View {
        HStack {
            Text(habit.emoji)
                .font(.system(size: 24))
                .padding(.trailing, 4)
            
            Text(habit.name)
                .foregroundColor(.white)
                .fontWeight(.medium)
            
            Spacer()
            
            if let duration = habit.deadlineDuration {
                let hours = duration / 3600
                let minutes = (duration % 3600) / 60
                Text(String(format: "%dh %02dm", hours, minutes))
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
            }
            
            Image(systemName: "repeat")
                .foregroundColor(habit.isRecurring ? .blue : .gray)
                .onTapGesture {
                    Task {
                        await viewModel.updateHabitRecurring(habit, isRecurring: !habit.isRecurring)
                    }
                }
            
            Text("+\(habit.xpPoints)")
                .foregroundColor(.green)
                .fontWeight(.semibold)
                .opacity(habit.isCompleted ? 1 : 0.4)
                .animation(.easeInOut(duration: 0.2), value: habit.isCompleted)
            
            ZStack {
                if habit.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .strokeBorder(.white.opacity(0.4), lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture {
                if !habit.isCompleted {
                    onProofRequest()
                }
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct ProofPopup: View {
    let habit: Habit
    let onUpload: (Data) async -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Beweise, dass du '\(habit.name)' erledigt hast")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Foto auswählen")
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            
            if let data = photoData {
                Button(action: {
                    Task {
                        await onUpload(data)
                    }
                }) {
                    Text("Absenden")
                        .padding()
                        .background(.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
