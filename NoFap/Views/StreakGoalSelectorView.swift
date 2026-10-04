//
//  StreakGoalSelectorView.swift
//  NoFap
//

import SwiftUI
import UIKit

struct StreakGoalSelectorView: View {
    @Binding var selected: Int

    var body: some View {
        VStack(spacing: 14) {
            ForEach(StreakTarget.allCases) { target in
                card(target)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selected)
    }

    private func card(_ target: StreakTarget) -> some View {
        let on = selected == target.days
        return Button {
            selected = target.days
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(l10n: target.dayBadge)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: 0xF2F2F5))
                    Spacer()
                    Text(l10n: target.badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(target.tint, in: Capsule())
                    if on {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(target.tint)
                    }
                }
                Text(l10n: target.title)
                    .font(Face.display(18, .semibold))
                    .foregroundStyle(Color(hex: 0xF2F2F5))
                Text(l10n: target.highlightQuote)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(target.tint)
                    .fixedSize(horizontal: false, vertical: true)
                fact("bolt.heart.fill", Color(hex: 0xFF5A36), target.bodyEffect)
                fact("brain.head.profile", Color(hex: 0x5BA8FF), target.mindEffect)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0x141418).opacity(on ? 1 : 0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(on ? target.tint : Color(hex: 0x2C2C34), lineWidth: on ? 2 : 1)
            }
            .shadow(color: on ? target.tint.opacity(0.35) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func fact(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(l10n: text)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0xE4E7EF))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
