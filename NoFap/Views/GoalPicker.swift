//
//  GoalPicker.swift
//  NoFap
//

import SwiftUI

struct GoalPicker: View {
    @Binding var selected: Int

    var body: some View {
        ScrollView {
            StreakGoalSelectorView(selected: $selected)
                .padding(.bottom, 8)
        }
        .scrollDisabled(false)
    }
}
