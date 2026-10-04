//
//  SOSPhysicalExercisesView.swift
//  NoFap
//

import AudioToolbox
import SwiftUI
import UIKit

struct SOSPhysicalExercisesView: View {
    var onHome: () -> Void

    @State private var selected: SOSExercise?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Физический сброс")
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Color(hex: 0xF2F2F5))
                Text("Выбери нагрузку и доведи её до конца. Импульс не переживёт жжение в мышцах.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: 0xC8C8D0))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(SOSExerciseLibrary.all) { exercise in
                    Button {
                        selected = exercise
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: exercise.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: 0xFF5A36))
                                .frame(width: 44, height: 44)
                                .background(Color(hex: 0xFF5A36).opacity(0.15), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(l10n: exercise.title)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(hex: 0xF2F2F5))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(l10n: exercise.targetRepsOrTime)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0xFF8A62))
                                Text(l10n: exercise.subtitle)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: 0xC8C8D0))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Color(hex: 0x141418), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color(hex: 0xFF5A36).opacity(0.45), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color(hex: 0x0A0A0D).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationDestination(item: $selected) { exercise in
            SOSExerciseSessionView(exercise: exercise, onHome: onHome)
        }
    }
}

private struct SOSExerciseSessionView: View {
    let exercise: SOSExercise
    var onHome: () -> Void

    @Environment(AvatarManager.self) private var avatar
    @State private var remaining = 0
    @State private var running = false
    @State private var reps = 0
    @State private var confirmed = false
    @State private var finished = false
    @State private var rewarded = false
    @State private var ticker: Task<Void, Never>?

    private var total: Int { exercise.durationSeconds ?? 0 }
    private var progress: Double {
        guard total > 0 else { return 0 }
        return 1 - Double(remaining) / Double(total)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: exercise.iconName)
                        .foregroundStyle(Color(hex: 0xFF5A36))
                    Text(l10n: exercise.title)
                        .font(Face.display(22, .semibold))
                        .foregroundStyle(Color(hex: 0xF2F2F5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(l10n: exercise.subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: 0xC8C8D0))
                    .fixedSize(horizontal: false, vertical: true)

                if finished {
                    doneCard
                } else if exercise.durationSeconds != nil {
                    timerBlock
                } else {
                    repsBlock
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(L10n.string(step))")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: 0xF2F2F5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(l10n: exercise.whyItWorks)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: 0xC8C8D0))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background(Color(hex: 0xFF5A36).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(20)
        }
        .background(Color(hex: 0x0A0A0D).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let seconds = exercise.durationSeconds {
                remaining = seconds
            }
        }
        .onDisappear { ticker?.cancel() }
    }

    private var timerBlock: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: 0xFF5A36).opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: 0xFF5A36), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                Text("\(remaining)")
                    .font(Face.display(40, .semibold))
                    .foregroundStyle(Color(hex: 0xF2F2F5))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }
            .frame(width: 180, height: 180)
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                sessionButton(running ? "Пауза" : "Старт") {
                    running ? pause() : start()
                }
                sessionButton("Сброс") { reset() }
            }
        }
    }

    private var repsBlock: some View {
        VStack(spacing: 14) {
            Text("\(reps)")
                .font(Face.display(56, .semibold))
                .foregroundStyle(Color(hex: 0xFF5A36))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(l10n: exercise.targetRepsOrTime)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0xC8C8D0))
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.snappy(duration: 0.2)) { reps += 1 }
            } label: {
                Text("Тап для шага")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: 0xFF5A36), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button {
                confirmed = true
                complete()
            } label: {
                Label(confirmed ? "Выполнено" : "Я выполнил все повторения", systemImage: confirmed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF2F2F5))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Импульс сломан. Кровь вернулась в мышцы. Отличная работа! 🔥")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: 0xF2F2F5))
                .fixedSize(horizontal: false, vertical: true)
            Text("+10 Power")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF5A36))
            Button("Вернуться на Главный экран", action: onHome)
                .buttonStyle(GoldButton())
        }
        .padding(16)
        .background(Color(hex: 0x141418), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sessionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(l10n: title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: 0xF2F2F5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: 0x2A2A32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func start() {
        guard remaining > 0 else { return }
        running = true
        ticker?.cancel()
        ticker = Task {
            while !Task.isCancelled && remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining -= 1
            }
            if remaining == 0 {
                running = false
                finishTimer()
            }
        }
    }

    private func pause() {
        running = false
        ticker?.cancel()
    }

    private func reset() {
        pause()
        remaining = total
    }

    private func finishTimer() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005)
        complete()
    }

    private func complete() {
        guard !rewarded else {
            finished = true
            return
        }
        rewarded = true
        finished = true
        avatar.addPowerForPhysicalReset()
    }
}
