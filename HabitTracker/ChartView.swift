//
//  ChartView.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//
import SwiftUI
import Charts

struct ChartView: View {
    @ObservedObject var viewModel: HabitViewModel
    @State private var xpValues: [Int] = [10, 20, 5, 30, 15, 25, 18]
    @State private var xpDays: [String] = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    
    private var categories: [(name: String, emoji: String, progress: Double)] {
        let grouped = Dictionary(grouping: viewModel.habits) { $0.category }
        return grouped.map { category, habits in
            let averageProgress = habits.map { $0.progress }.reduce(0, +) / Double(max(1, habits.count))
            return (name: category, emoji: habits.first?.emoji ?? "⭐️", progress: averageProgress)
        }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
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
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        
                        PointMark(
                            x: .value("Tag", xpDays[index]),
                            y: .value("XP", xpValues[index])
                        )
                        .foregroundStyle(.green)
                        .symbolSize(30)
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(preset: .aligned, position: .bottom) { _ in
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.6))
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
        .background(.black.opacity(0.5))
        
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(height: 1)
            .padding(.bottom, 8)
    }
}

#Preview {
    ChartView(viewModel: HabitViewModel())
}
