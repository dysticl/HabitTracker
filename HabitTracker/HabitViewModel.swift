import Foundation
import SwiftUI

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var xpPoints: Int
    var isCompleted: Bool
    var progress: Double
    var isRecurring: Bool
    var deadlineDuration: Int? // Neue Eigenschaft für Deadline in Sekunden
    var pendingDeletion: Bool
    
    static func ==(lhs: Habit, rhs: Habit) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case xpPoints = "xp_points"
        case isCompleted
        case progress
        case isRecurring
        case deadlineDuration = "deadline_duration"
        case pendingDeletion
    }
}

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isAdding: Bool = false
    @Published var newHabitName: String = ""
    @Published var newHabitEmoji: String = ""
    @Published var newHabitDeadlineHours: String = "" // Neue Eigenschaft für UI-Eingabe (Stunden)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    func fetchHabits() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let fetchedHabits = try await APIManager.shared.fetchHabits()
            await MainActor.run {
                self.habits = fetchedHabits.compactMap { apiHabit in
                    guard let uuid = UUID(uuidString: apiHabit.id) else {
                        print("Fehler: Ungültige UUID \(apiHabit.id)")
                        return nil
                    }
                    // Nur nicht-abgeschlossene oder wiederkehrende Habits anzeigen
                    guard !apiHabit.isCompleted || apiHabit.isRecurring else { return nil }
                    return Habit(
                        id: uuid,
                        name: apiHabit.name,
                        emoji: apiHabit.emoji,
                        xpPoints: apiHabit.xpPoints,
                        isCompleted: apiHabit.isCompleted,
                        progress: apiHabit.progress,
                        isRecurring: apiHabit.isRecurring,
                        deadlineDuration: apiHabit.deadlineDuration,
                        pendingDeletion: false
                    )
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Laden der Habits: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Fetch habits error: \(error)")
        }
    }
    
    func uploadProof(for habit: Habit, photoData: Data) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let updatedHabit = try await APIManager.shared.uploadProof(habitId: habit.id.uuidString, photoData: photoData)
            await MainActor.run {
                if !habit.isRecurring {
                    // Nicht wiederkehrendes Habit wurde gelöscht, lokal entfernen
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.habits.removeAll { $0.id == habit.id }
                    }
                } else if let updatedHabit = updatedHabit {
                    // Wiederkehrendes Habit wurde aktualisiert, Status lokal aktualisieren
                    if let index = self.habits.firstIndex(where: { $0.id == habit.id }) {
                        guard let uuid = UUID(uuidString: updatedHabit.id) else {
                            self.errorMessage = "Ungültige UUID vom Server: \(updatedHabit.id)"
                            self.isLoading = false
                            return
                        }
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.habits[index] = Habit(
                                id: uuid,
                                name: updatedHabit.name,
                                emoji: updatedHabit.emoji,
                                xpPoints: updatedHabit.xpPoints,
                                isCompleted: updatedHabit.isCompleted,
                                progress: updatedHabit.progress,
                                isRecurring: updatedHabit.isRecurring,
                                deadlineDuration: updatedHabit.deadlineDuration,
                                pendingDeletion: false
                            )
                        }
                    }
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Hochladen des Beweises: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Upload proof error: \(error)")
        }
    }
    
    func toggleHabit(_ habit: Habit) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            await MainActor.run {
                self.errorMessage = "Habit nicht gefunden"
                self.isLoading = false
            }
            return
        }
        
        // Lokalen Status vorübergehend aktualisieren
        await MainActor.run {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.habits[index].isCompleted.toggle()
            }
        }
        
        do {
            let apiHabit = APIHabit(
                id: habit.id.uuidString,
                name: habit.name,
                emoji: habit.emoji,
                xpPoints: habit.xpPoints,
                isCompleted: habits[index].isCompleted,
                progress: habit.progress,
                isRecurring: habit.isRecurring,
                deadlineDuration: habit.deadlineDuration
            )
            let updatedHabit = try await APIManager.shared.updateHabit(apiHabit)
            
            await MainActor.run {
                if let currentIndex = self.habits.firstIndex(where: { $0.id == habit.id }) {
                    guard let uuid = UUID(uuidString: updatedHabit.id) else {
                        self.errorMessage = "Ungültige UUID vom Server: \(updatedHabit.id)"
                        self.isLoading = false
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.habits[currentIndex] = Habit(
                            id: uuid,
                            name: updatedHabit.name,
                            emoji: updatedHabit.emoji,
                            xpPoints: updatedHabit.xpPoints,
                            isCompleted: updatedHabit.isCompleted,
                            progress: updatedHabit.progress,
                            isRecurring: updatedHabit.isRecurring,
                            deadlineDuration: updatedHabit.deadlineDuration,
                            pendingDeletion: false
                        )
                    }
                }
            }
            
            // Nicht wiederkehrende, abgeschlossene Habits löschen
            if habits[index].isCompleted && !habits[index].isRecurring {
                do {
                    try await APIManager.shared.deleteHabit(id: habit.id.uuidString)
                    await MainActor.run {
                        if let currentIndex = self.habits.firstIndex(where: { $0.id == habit.id }) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                self.habits[currentIndex].pendingDeletion = true
                            }
                        }
                    }
                    // Verzögerte Entfernung für Animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let deleteIndex = self.habits.firstIndex(where: { $0.id == habit.id }) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                self.habits.remove(at: deleteIndex)
                            }
                        }
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Fehler beim Löschen des Habits: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    print("Delete habit error: \(error)")
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Aktualisieren des Habits: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Toggle habit error: \(error)")
        }
    }
    
    func addHabit() {
        guard !newHabitName.isEmpty else {
            errorMessage = "Habit-Name darf nicht leer sein"
            return
        }
        
        let defaultEmojis = ["⭐️", "🔥", "💪", "📘", "☀️", "🧠", "📈", "🏆"]
        let selectedEmoji = newHabitEmoji.isEmpty ? defaultEmojis.randomElement() ?? "⭐️" : newHabitEmoji
        
        // Deadline-Dauer aus Stunden in Sekunden umrechnen
        let deadlineDuration: Int?
        if let hours = Int(newHabitDeadlineHours), hours > 0 {
            deadlineDuration = hours * 3600 // Stunden in Sekunden
        } else {
            deadlineDuration = nil
        }
        
        let newHabit = APIHabitCreate(
            name: newHabitName,
            emoji: selectedEmoji,
            xpPoints: 10,
            isCompleted: false,
            progress: 0.0,
            isRecurring: false,
            deadlineDuration: deadlineDuration
        )
        
        Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                let apiHabit = try await APIManager.shared.createHabit(newHabit)
                guard let uuid = UUID(uuidString: apiHabit.id) else {
                    await MainActor.run {
                        self.errorMessage = "Ungültige UUID vom Server: \(apiHabit.id)"
                        self.isLoading = false
                        self.isAdding = false
                    }
                    return
                }
                if self.habits.contains(where: { $0.id == uuid }) {
                    await MainActor.run {
                        self.errorMessage = "Duplizierte Habit-ID erhalten"
                        self.isLoading = false
                        self.isAdding = false
                    }
                    return
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.habits.append(Habit(
                            id: uuid,
                            name: apiHabit.name,
                            emoji: apiHabit.emoji,
                            xpPoints: apiHabit.xpPoints,
                            isCompleted: apiHabit.isCompleted,
                            progress: apiHabit.progress,
                            isRecurring: apiHabit.isRecurring,
                            deadlineDuration: apiHabit.deadlineDuration,
                            pendingDeletion: false
                        ))
                        self.newHabitName = ""
                        self.newHabitEmoji = ""
                        self.newHabitDeadlineHours = ""
                        self.isAdding = false
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Fehler beim Hinzufügen des Habits: \(error.localizedDescription)"
                    self.isLoading = false
                    self.isAdding = false
                }
                print("Add habit error: \(error)")
            }
        }
    }
}
