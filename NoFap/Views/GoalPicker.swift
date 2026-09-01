//
//  GoalPicker.swift
//  NoFap
//
//  Выбор личного срока воздержания — используется и в онбординге, и позже
//  при редактировании цели с экрана «Прогресс». Пресеты + своё число,
//  без навязанного «идеального» срока.
//

import SwiftUI

struct GoalPicker: View {

    @Binding var selected: Int

    @State private var customText: String = ""
    @FocusState private var customFocused: Bool

    private let presets = [7, 14, 21, 30, 60, 90]

    private var isCustomActive: Bool {
        !presets.contains(selected)
    }

    var body: some View {
        VStack(spacing: 22) {
            Text("Поставил цель — добейся")
                .font(Face.display(24, .medium))
                .foregroundStyle(Palette.marbleHigh)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Выбери срок сам. Это твоя цель, не наша.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(presets, id: \.self) { days in
                    presetCell(days)
                }
            }

            HStack(spacing: 10) {
                Text("Своё число:")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)

                TextField("21", text: $customText)
                    .keyboardType(.numberPad)
                    .focused($customFocused)
                    .font(Face.display(18, .medium))
                    .foregroundStyle(isCustomActive ? Palette.gold : Palette.marbleHigh)
                    .multilineTextAlignment(.center)
                    .frame(width: 64, height: 44)
                    .background(Palette.basalt, in: .rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isCustomActive ? Palette.gold : Palette.vein, lineWidth: 1)
                    }
                    .onChange(of: customText) { _, newValue in
                        let digits = newValue.filter(\.isNumber).prefix(3)
                        customText = String(digits)
                        if let value = Int(digits), value > 0 {
                            selected = value
                        }
                    }

                Text("дней")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)
            }
        }
        .onAppear {
            if isCustomActive { customText = "\(selected)" }
        }
    }

    private func presetCell(_ days: Int) -> some View {
        let isSelected = selected == days

        return Button {
            selected = days
            customText = ""
            customFocused = false
        } label: {
            Text("\(days)")
                .font(Face.display(20, .semibold))
                .foregroundStyle(isSelected ? Color(hex: 0x1A1405) : Palette.marbleHigh)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14).fill(.goldFill)
                    } else {
                        RoundedRectangle(cornerRadius: 14).fill(Palette.basalt)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isSelected ? Color.clear : Palette.vein, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
