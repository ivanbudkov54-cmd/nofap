//
//  ContrastExperimentView.swift
//  NoFap
//

import SwiftUI

struct ContrastExperimentView: View {

    @Environment(ContrastExperimentManager.self) private var experiment
    @Environment(JournalManager.self) private var journal
    @Environment(CloudSync.self) private var backend

    @State private var showReview = false

    private let accent = Color(hex: 0x8B7CFF)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            card(now: context.date)
                .onChange(of: context.date) { _, now in
                    experiment.refreshIfCooldownElapsed(now: now)
                }
        }
        .animation(.easeInOut(duration: 0.35), value: experiment.state)
        .sheet(isPresented: $showReview) {
            ContrastReflectionSheet { energy, feelings, comparison in
                let review = experiment.complete(energy: energy, feelings: feelings, comparison: comparison)
                let note = ContrastExperimentManager.journalNote(for: review)
                let prompt = "Эксперимент: Осознание контраста"
                journal.addEntry(note, promptQuestion: prompt, moodScore: review.energy)
                Task {
                    await backend.saveJournal(mood: review.energy, urge: nil, prompt: prompt, note: note, into: journal)
                }
                showReview = false
            }
        }
        .onAppear {
            experiment.refreshIfCooldownElapsed()
        }
    }

    private func card(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Специальный эксперимент")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accent.opacity(0.16), in: Capsule())

            content(now: now)
        }
        .padding(16)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(0.45), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch experiment.state {
        case .notStarted:
            Text("Эксперимент: Осознание контраста")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)
            Text("Практика парадоксального наблюдения: сними любые ограничения на один день, доведя импульс до полного пресыщения. После этого остановись и на контрасте отследи, как меняется твоя биохимия и фокус.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
            actionButton("Начать эксперимент") {
                experiment.start()
            }

        case .activeWaitingReset:
            Text("Эксперимент: Осознание контраста")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)
            Text("Эксперимент запущен. Когда завершишь цикл, нажми кнопку ниже, чтобы запустить таймер чистоты и сравнения.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
            actionButton("Завершил. Начать отсчет контраста") {
                experiment.beginContrast()
            }

        case .coolingDown(let startedAt, let duration):
            let remaining = max(0, startedAt.addingTimeInterval(duration).timeIntervalSince(now))
            let progress = duration > 0 ? min(1, max(0, 1 - remaining / duration)) : 1
            HStack(spacing: 16) {
                ContrastTimerRing(progress: progress, label: Self.clock(remaining))
                Text("Наблюдай за возвращением энергии и ясности ума. Опрос сравнения откроется через \(Self.clock(remaining)).")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.marble)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .readyForReview:
            Text("Время сравнить ощущения! 📊")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)
            Text("Сутки наблюдения прошли. Зафиксируй, чем сегодняшнее состояние отличается от момента срыва.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
            actionButton("Пройти сравнительный разбор") {
                showReview = true
            }

        case .completed(let review):
            Text("Вывод сохранён")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Text("Энергия и ясность: \(review.energy)/10")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
            if !review.feelings.isEmpty {
                Text(review.feelings.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)
            }
            Text(review.comparison)
                .font(.system(size: 14))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Palette.basalt)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.28), Color(hex: 0x2A3148).opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    private static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

private struct ContrastTimerRing: View {
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: 0x8B7CFF).opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(hex: 0x8B7CFF), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.marbleHigh)
                .monospacedDigit()
        }
        .frame(width: 84, height: 84)
    }
}

struct ContrastReflectionSheet: View {
    let onSave: (Int, [String], String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var energy = 5.0
    @State private var feelings: Set<String> = []
    @State private var comparison = ""

    private let options = ["Апатия", "Стыд", "Сонливость", "Туман в голове", "Потеря мотивации"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Уровень физической энергии и ясности мыслей прямо сейчас")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        HStack {
                            Text("1")
                            Slider(value: $energy, in: 1...10, step: 1)
                            Text("10")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ash)
                        Text("\(Int(energy)) из 10")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x8B7CFF))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Что ты чувствовал сразу после сброса?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        FlowFeelings(options: options, selected: $feelings)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сравни это ощущение с состоянием, когда ты держишь стрик. Стоила ли сиюминутная слабость такого отката?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                            .fixedSize(horizontal: false, vertical: true)
                        TextEditor(text: $comparison)
                            .font(.system(size: 16))
                            .foregroundStyle(Palette.marbleHigh)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(10)
                            .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Palette.vein, lineWidth: 1)
                            }
                    }

                    Button {
                        onSave(Int(energy), options.filter { feelings.contains($0) }, comparison)
                    } label: {
                        Text("Зафиксировать вывод")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x1A1405))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(comparison.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(comparison.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationTitle("Сравнительный разбор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct FlowFeelings: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = selected.contains(option)
                Button {
                    if on {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                } label: {
                    HStack {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? Color(hex: 0x8B7CFF) : Palette.ash)
                        Text(option)
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.marbleHigh)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
