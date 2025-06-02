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
    var deadlineDuration: Int?
    var pendingDeletion: Bool
    var category: String
    
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
        case category
    }
}

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isAdding: Bool = false
    @Published var newHabitName: String = ""
    @Published var newHabitDeadlineHours: String = ""
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
                        pendingDeletion: false,
                        category: apiHabit.category
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
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.habits.removeAll { $0.id == habit.id }
                    }
                } else if let updatedHabit = updatedHabit {
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
                                pendingDeletion: false,
                                category: updatedHabit.category
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
                deadlineDuration: habit.deadlineDuration,
                category: habit.category
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
                            pendingDeletion: false,
                            category: updatedHabit.category
                        )
                    }
                }
            }
            
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
    
    func updateHabitRecurring(_ habit: Habit, isRecurring: Bool) async {
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
        
        await MainActor.run {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.habits[index].isRecurring = isRecurring
            }
        }
        
        do {
            let apiHabit = APIHabit(
                id: habit.id.uuidString,
                name: habit.name,
                emoji: habit.emoji,
                xpPoints: habit.xpPoints,
                isCompleted: habit.isCompleted,
                progress: habit.progress,
                isRecurring: isRecurring,
                deadlineDuration: habit.deadlineDuration,
                category: habit.category
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
                            pendingDeletion: false,
                            category: updatedHabit.category
                        )
                    }
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Aktualisieren des Habits: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Update recurring error: \(error)")
        }
    }
    
    func addHabit() {
        guard !newHabitName.isEmpty else {
            errorMessage = "Habit-Name darf nicht leer sein"
            return
        }
        
        let deadlineDuration: Int?
        if let hours = Int(newHabitDeadlineHours), hours > 0 {
            deadlineDuration = hours * 3600
        } else {
            deadlineDuration = nil
        }
        
        let newHabit = APIHabitCreate(
            name: newHabitName,
            emoji: "⭐️",
            xpPoints: 10,
            isCompleted: false,
            progress: 0.0,
            isRecurring: false,
            deadlineDuration: deadlineDuration,
            category: "Allgemein"
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
                        self.habits.insert(Habit(
                            id: uuid,
                            name: apiHabit.name,
                            emoji: apiHabit.emoji,
                            xpPoints: apiHabit.xpPoints,
                            isCompleted: apiHabit.isCompleted,
                            progress: apiHabit.progress,
                            isRecurring: apiHabit.isRecurring,
                            deadlineDuration: apiHabit.deadlineDuration,
                            pendingDeletion: false,
                            category: apiHabit.category
                        ), at: 0)
                        self.newHabitName = ""
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
