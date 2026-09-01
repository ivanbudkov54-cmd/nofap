//
//  CheckInView.swift
//  NoFap
//

import SwiftUI

struct CheckInView: View {

    @Environment(StreakManager.self) private var streak
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Как прошёл день?")
                .font(Face.display(28, .medium))
                .foregroundStyle(.marbleFill)
                .padding(.top, 34)

            Text("Отметка остаётся на этом телефоне. Её никто не увидит.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer()

            Button("ДЕРЖАЛСЯ") {
                streak.checkIn(clean: true)
                dismiss()
            }
            .buttonStyle(EngravedButton())

            Button("БЫЛ СРЫВ") {
                streak.checkIn(clean: false)
                dismiss()
            }
            .buttonStyle(StoneButton())
            .padding(.top, 10)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 26)
        .background(Palette.basalt)
    }
}
