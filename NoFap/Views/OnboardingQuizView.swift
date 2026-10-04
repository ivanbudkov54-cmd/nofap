//
//  OnboardingQuizView.swift
//  NoFap
//

import SwiftUI
import UIKit

struct OnboardingQuizView: View {

    @Environment(JournalManager.self) private var journal
    @Environment(StreakManager.self) private var streak
    @Environment(Backend.self) private var backend

    let onFinish: () -> Void

    @State private var page = 0
    @State private var duration: String?
    @State private var triggers: [String] = []
    @State private var costs: [String] = []
    @State private var pastRecord: String?
    @State private var goals: [String] = []
    @State private var targetDays: Int?
    @State private var generating = false
    @State private var generated = false
    @State private var statusLine = "Анализ твоих триггеров..."

    private let durations = ["Меньше 1 года", "1–3 года", "3–7 лет", "Более 7 лет"]
    private let triggerOptions = ["Поздно вечером в кровати", "Стресс и выгорание", "От скуки", "Бесцельный скроллинг соцсетей", "Одиночество"]
    private let costOptions = ["Физическую энергию", "Уверенность с девушками", "Фокус и продуктивность", "Самоуважение", "Радость от простых вещей"]
    private let records = ["Никогда не пробовал", "1–3 дня", "1–2 недели", "30+ дней"]
    private let goalOptions = ["Чистый взгляд и здоровая сексуальная энергия", "Уверенность и знакомства с девушками", "Дисциплина в спорте и бизнесе", "Контроль над разумом и телом"]
    private let lastQuestion = 6
    private let finale = 7

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $page) {
                disclaimer.tag(0)
                question(
                    title: "Как давно эта привычка присутствует в твоей жизни?",
                    options: durations,
                    selected: duration.map { [$0] } ?? [],
                    limit: 1
                ) { toggleSingle($0, into: &duration) }
                .tag(1)
                question(
                    title: "В какие моменты импульс срывает твою защиту чаще всего?",
                    options: triggerOptions,
                    selected: triggers,
                    limit: nil
                ) { toggle($0, in: &triggers, limit: nil) }
                .tag(2)
                question(
                    title: "Что эта привычка отнимает у тебя прямо сейчас?",
                    options: costOptions,
                    selected: costs,
                    limit: nil
                ) { toggle($0, in: &costs, limit: nil) }
                .tag(3)
                question(
                    title: "Какой твой максимальный рекорд осознанного воздержания в прошлом?",
                    options: records,
                    selected: pastRecord.map { [$0] } ?? [],
                    limit: 1
                ) { toggleSingle($0, into: &pastRecord) }
                .tag(4)
                question(
                    title: "Ради чего главного ты хочешь освободиться от зависимости?",
                    options: goalOptions,
                    selected: goals,
                    limit: 2
                ) { toggle($0, in: &goals, limit: 2) }
                .tag(5)
                dayQuestion.tag(6)
                finaleScreen.tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: page)

            footer
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .onChange(of: page) { _, newValue in
            if newValue == finale { startGeneration() }
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if page > 0 && !generated {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) { page -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if page > 0 {
                    Text("\(min(page, 7))/7")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ash)
                }
            }
            if page > 0 {
                ProgressView(value: Double(min(page, 7)), total: 7)
                    .tint(Palette.gold)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text("Диагностика твоего пути")
                .font(Face.display(28, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)
            Text("Этот опрос нужен для честного осознания твоих триггеров, слабых мест и фиксации точки А, из которой ты начинаешь свой путь.")
                .font(.system(size: 16))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(24)
    }

    private func question(
        title: String,
        options: [String],
        selected: [String],
        limit: Int?,
        onTap: @escaping (String) -> Void
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(l10n: title)
                    .font(Face.display(22, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)
                if limit == 2 {
                    Text("Можно выбрать до двух")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ash)
                }
                ForEach(options, id: \.self) { option in
                    chip(option, on: selected.contains(option)) {
                        onTap(option)
                    }
                }
            }
            .padding(24)
        }
    }

    private var dayQuestion: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Сколько дней чистоты ты ставишь своей первой целью?")
                    .font(Face.display(22, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)
                StreakGoalSelectorView(selected: Binding(
                    get: { targetDays ?? 0 },
                    set: { targetDays = $0 }
                ))
            }
            .padding(24)
        }
        .scrollDisabled(false)
    }

    private var finaleScreen: some View {
        VStack(spacing: 18) {
            Spacer()
            if generated {
                Image(systemName: "flag.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Palette.gold)
                Text("Твоя отправная точка зафиксирована. Сегодня — твой первый день свободы")
                    .font(Face.display(24, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(Palette.gold)
                Text(statusLine)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.marble)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.35), value: statusLine)
            }
            Spacer()
        }
        .padding(24)
    }

    private var footer: some View {
        Button(action: advance) {
            Text(buttonTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canAdvance ? Color(hex: 0x1A1405) : Palette.ash)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canAdvance ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(Palette.vein),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .disabled(!canAdvance)
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
        .padding(.top, 8)
    }

    private var buttonTitle: String {
        if page == 0 { return "Начать диагностику" }
        if page == finale { return "Войти в приложение" }
        return "Далее"
    }

    private var canAdvance: Bool {
        switch page {
        case 0: true
        case 1: duration != nil
        case 2: !triggers.isEmpty
        case 3: !costs.isEmpty
        case 4: pastRecord != nil
        case 5: !goals.isEmpty
        case 6: targetDays != nil
        case finale: generated
        default: false
        }
    }

    private func advance() {
        if page == finale {
            saveAndEnter()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
    }

    private func startGeneration() {
        guard !generating, !generated else { return }
        generating = true
        statusLine = "Анализ твоих триггеров..."
        Task {
            try? await Task.sleep(for: .seconds(1.25))
            statusLine = "Формирование профиля дисциплины..."
            try? await Task.sleep(for: .seconds(1.25))
            generated = true
        }
    }

    private func saveAndEnter() {
        guard let duration, let pastRecord, let targetDays else { return }
        let note = """
        #ТочкаА #Манифест
        Я начинаю свой путь освобождения. Вот моя честная диагностика на старте:

        ⏳ Стаж зависимости: \(duration)
        ⚠️ Мои главные триггеры: \(triggers.joined(separator: ", "))
        🛑 Что привычка отнимает у меня: \(costs.joined(separator: ", "))
        🏆 Прошлый рекорд воздержания: \(pastRecord)
        🎯 Моя главная цель (Точка Б): \(goals.joined(separator: ", "))
        🔥 Первая планка: \(targetDays) дней чистоты подряд — \(StreakTarget(rawValue: targetDays)?.title ?? "")

        Я фиксирую это здесь, чтобы перечитывать эту запись в моменты слабости и помнить, почему я начал.
        """
        journal.addManifest(note)
        streak.setGoal(targetDays)
        let prompt = JournalEntry.manifestBadge
        Task {
            await backend.saveJournal(mood: nil, urge: nil, prompt: prompt, note: note, into: journal)
        }
        onFinish()
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(l10n: title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(on ? Color(hex: 0x1A1405) : Palette.marbleHigh)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Color(hex: 0x1A1405) : Palette.ash)
            }
            .padding(14)
            .background(on ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(Palette.basalt), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? Color.clear : Palette.vein, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleSingle(_ option: String, into value: inout String?) {
        value = option
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func toggle(_ option: String, in list: inout [String], limit: Int?) {
        if let index = list.firstIndex(of: option) {
            list.remove(at: index)
        } else if let limit, list.count >= limit {
            return
        } else {
            list.append(option)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
