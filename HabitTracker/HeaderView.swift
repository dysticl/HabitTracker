//
//  HeaderView.swift
//  HabitTracker
//
//  Created by Daniel Kasanzew on 02.06.25.
//

import SwiftUI

struct HeaderView: View {
    @State private var currentStreak: Int = 3
    
    var body: some View {
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
    }
}

#Preview {
    HeaderView()
}
