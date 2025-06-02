import SwiftUI
import Charts
import PhotosUI
import AuthenticationServices

struct ContentView: View {
    @StateObject private var viewModel = HabitViewModel()
    @State private var timeRemaining: Int = 3600
    @State private var currentStreak: Int = 3
    @State private var xpValues: [Int] = [10, 20, 5, 30, 15, 25, 18]
    @State private var xpDays: [String] = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    @State private var proofHabitId: UUID? = nil
    
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
        if viewModel.isLoggedIn {
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
                                        HabitRow(habit: $habit, onProofRequest: {
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
                    
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("XP")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Chart {
                                ForEach(0..<xpValues.count), id: \.self) { index in
                                    LineMark(
                                        x: .value("Tag", xpDays[index]),
                                        y: .value("XP", xpValues[index])
                                    .foregroundStyle(.green)
                                    .lineStyle(.init(lineWidth: 2.5)))
                                    
                                    PointMark(
                                        x: .value("Tag", xpDays[index]),
                                        y: .value("XP", xpValues[index]))
                                    .foregroundStyle(.green)
                                    .symbolSize(.init(30)))
                                }
                            }
                            .chartYAxis(.hidden)
                            .chartXAxis {
                                AxisMarks(preset: .aligned, position: .bottom) { _ in
                                    AxisValueLabel()
                                        .foregroundStyle(.white.opacity(0.7))
                                        .font(.system(size: 10))
                                }
                            }
                            .frame(height: 60)
                            .cornerRadius(20)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 8) {
                            ForEach(categories, id: \.name) { category in
                                HStack {
                                    Text(category.emoji)
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(.white.opacity(0))
                                                .frame(height: 40)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(.green)
                                                .frame(width: geometry.size.width * max(0.0, min(1.1, max(category.progress))), height: 20)
                                        }
                                    }
                                    .frame(height: 16)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.black.opacity(0.5)))
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        
 .padding(.bottom, 8)
                    
                    HStack {
                        TabBarItem(name: "flame", label: "Favorites")
                        TabBarItem(name: "flag", label: "Tasks")
                        TabBarItem(name: "person.3", label: "Friends")
                        TabBarItem(name: "gear", label: "Settings")
                            }
                    .padding(.bottom, 16)
                    }
                    .ignoresSafeArea()
                    .onAppear {
                        Task {
                            await viewModel.fetchHabits()
                        }
                    }
                    .onChange(of: viewModel.habits) { _ in
                        updateTimerForActiveHabit()
                    }
                    .alert(isPresented: .constant(Binding(
                        get: { viewModel.errorMessage != nil },
                        set: { if !$0 { viewModel.errorMessage = nil } }
                    ))) {
                        Alert(
                            title: Text("Error"),
                            message: Text(viewModel.errorMessage ?? "Some error"),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
        } else {
            VStack {
                Text("Bitte mit Apple anmelden")
                    .font(.title2)
                    .padding()
                
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            await viewModel.signInWithApple()
                        }
                    }
                )
                .frame(height: 45)
                .padding(.horizontal)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
    }
    
    private func updateTimerForActiveHabit() {
        if let activeHabit = activeHabitWithDeadline,
           let deadlineDuration = activeHabit.deadlineDuration {
            timeRemaining = max(0, deadlineDuration)
        } else {
            timeRemaining = 3600
        }
    }
}

struct HabitRow: View {
    @Binding var habit: Habit
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
                
                .frame(width:spacing)
                if let duration = habit.deadlineDuration {
                    Text(String(format: "%dh %dmh", duration / 3600, (duration % 3600) / 60))
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
                }
                
                Image(systemName: "repeat")
                    .foregroundColor(habit.isRecurring ? .blue : .gray)
                    .onTapGesture {
                        habit.isRecurring.toggle()
                    }
                
                Text("+\(value:habit.xpPoints)")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                    .opacity(habit.isCompleted ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.2), value: habit.isCompleted)
                
                ZStack {
                    if habit.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                            .transition(.scale)
                    } else {
                        Circle()
                            .strokeBorder(.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .transition(.scale)
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
            let name: String
            let label: String
            
            var body: some View {
                VStack(spacing: 4) {
                    Image(systemName: name)
                        .foregroundColor(.white)
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        
        struct BlurView: UIViewRepresentable {
            var style: UIBlurEffectStyle
            
            func makeUIView(context _: Context) -> UIVisualEffectView {
                return UIVisualEffectView(effect: .init(UIBlurEffect(style: style)))
            }
            
            func updateUIView(_ uiView: UIVisualEffectView, context _: Context) {}
        }
        
        struct ProofPopup: View {
            let habit: Habit
            let onUpload: (Data) async -> Void
            @State private var selectedPhoto: PhotosPickerItem? = nil
            @State private var photoData: Data? = nil
            
            var body: some View {
                VStack(spacing: 20) {
                    Text("Prove that you've completed '\(value:habit.name)'")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text("Select Photo")
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    photoData = data
                                }
                            }
                        }
                    
                    if photoData != nil {
                        Button(action: {
                            if let data = photoData {
                                Task {
                                    await onUpload(data)
                                }
                            }
                        }) {
                            Text("Submit")
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
