//
//  OnboardingQuizView.swift
//  NoFap
//

import SwiftUI
import UIKit

struct OnboardingQuizView: View {

    @Environment(JournalManager.self) private var journal
    @Environment(StreakManager.self) private var streak
    @Environment(CloudSync.self) private var backend
    @Environment(ManifestManager.self) private var manifest

    let onFinish: () -> Void

    @State private var page = 0
    @State private var duration: String?
    @State private var triggers: [String] = []
    @State private var costs: [String] = []
    @State private var pastRecord: String?
    @State private var goals: [String] = []
    @State private var relapseFeelings: [String] = []
    @State private var customFeeling = ""
    @State private var yearLosses: [String] = []
    @State private var futureChoice: String?
    @State private var futureNote = ""
    @State private var targetDays: Int?
    @State private var generating = false
    @State private var generated = false
    @State private var statusLine = "Анализ твоих триггеров..."
    @State private var showDecision = false
    @State private var goingBack = false
    @FocusState private var focusedField: Field?

    private enum Field { case feeling, future }

    private let durations = ["Меньше 1 года", "1–3 года", "3–7 лет", "Более 7 лет"]
    private let triggerOptions = ["Поздно вечером в кровати", "Стресс и выгорание", "От скуки", "Бесцельный скроллинг соцсетей", "Одиночество"]
    private let costOptions = ["Физическую энергию", "Уверенность с девушками", "Фокус и продуктивность", "Самоуважение", "Радость от простых вещей"]
    private let records = ["Никогда не пробовал", "1–3 дня", "1–2 недели", "30+ дней"]
    private let goalOptions = ["Чистый взгляд и здоровая сексуальная энергия", "Уверенность и знакомства с девушками", "Дисциплина в спорте и бизнесе", "Контроль над разумом и телом"]
    private let dayOptions = [7, 14, 30, 90]

    private let feelingOptions = [
        "🌫️ Ватный туман в голове",
        "🕳️ Полная душевная пустота",
        "📉 Резкая физическая слабость",
        "💔 Отвращение к себе и стыд",
        "⏳ Осознание слитого впустую времени"
    ]
    private let lossOptions = [
        "🥀 Уверенность и раскованность с девушками",
        "⚡ Драйв и энергия для бизнеса / учебы",
        "⏳ Сотни часов вычеркнутой жизни",
        "🧬 Тестостерон, выносливость и форма",
        "🎯 Глубокий фокус и память"
    ]
    // Цель вместо страшилки «кем станешь через 5 лет»: сравнивать себя
    // с худшей версией не мотивирует, а образ, к которому идёшь, — да.
    private let futureOptions = [
        "Спокойным и собранным: голова ясная, тревога ушла.",
        "Уверенным в себе — с девушками, с людьми, в деле.",
        "Энергичным: силы есть на спорт, работу и свои цели.",
        "Хозяином своего времени, а не экрана."
    ]
    private let contractPage = 8
    private let finale = 10

    var body: some View {
        VStack(spacing: 0) {
            topBar
            // Не TabView: при быстром «Далее» он не успевал долистать —
            // счётчик показывал следующий вопрос, а на экране оставался
            // прежний, и ответ уходил не туда.
            ZStack {
                pageView(page)
                    .id(page)
                    .transition(.push(from: goingBack ? .leading : .trailing))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            footer
        }
        .background { StoneBackground() }
        // Клавиатура не поднимает кнопку: иначе она наезжает на поле.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: page) { _, newValue in
            focusedField = nil
            if newValue == finale { startGeneration() }
        }
        .fullScreenCover(isPresented: $showDecision) {
            ManifestDecisionView {
                UserDefaults.standard.set(true, forKey: "has_completed_quiz")
                showDecision = false
                saveAndEnter()
            }
        }
    }

    @ViewBuilder
    private func pageView(_ index: Int) -> some View {
        switch index {
        case 0: disclaimer
        case 1:
            question(
                title: "Как давно эта привычка присутствует в твоей жизни?",
                options: durations,
                selected: duration.map { [$0] } ?? [],
                limit: 1
            ) { toggleSingle($0, into: &duration) }
        case 2:
            question(
                title: "В какие моменты импульс срывает твою защиту чаще всего?",
                options: triggerOptions,
                selected: triggers,
                limit: nil
            ) { toggle($0, in: &triggers, limit: nil) }
        case 3:
            question(
                title: "Что эта привычка отнимает у тебя прямо сейчас?",
                options: costOptions,
                selected: costs,
                limit: nil
            ) { toggle($0, in: &costs, limit: nil) }
        case 4:
            question(
                title: "Какой твой максимальный рекорд осознанного воздержания в прошлом?",
                options: records,
                selected: pastRecord.map { [$0] } ?? [],
                limit: 1
            ) { toggleSingle($0, into: &pastRecord) }
        case 5:
            question(
                title: "Ради чего главного ты хочешь освободиться от зависимости?",
                options: goalOptions,
                selected: goals,
                limit: 2
            ) { toggle($0, in: &goals, limit: 2) }
        case 6: feelingStep
        case 7: lossStep
        case 8: futureStep
        case 9: dayQuestion
        default: finaleScreen
        }
    }

    /// Направление выставляется до смены страницы: уходящий экран берёт
    /// переход из прошлого кадра, иначе «назад» уезжал бы не в ту сторону.
    /// Цель считается сразу: двойное касание «Далее» не перепрыгнет вопрос.
    private func go(by step: Int) {
        let target = min(max(page + step, 0), finale)
        goingBack = step < 0
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.3)) { page = target }
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Высота строки постоянная: на финале стрелка «назад» исчезает,
            // и без этого счётчик с полосой подпрыгивали вверх.
            HStack {
                if page > 0 && !generated {
                    Button {
                        go(by: -1)
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
                    Text("\(min(page, finale))/\(finale)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ash)
                }
            }
            .frame(height: 36)
            if page > 0 {
                ProgressView(value: Double(min(page, finale)), total: Double(finale))
                    .tint(Palette.gold)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text("Диагностика твоего пути")
                .font(Face.display(34, .medium))
                .foregroundStyle(.marbleFill)
                .fixedSize(horizontal: false, vertical: true)
            Text("Этот опрос нужен для честного осознания твоих триггеров, слабых мест и фиксации точки А, из которой ты начинаешь свой путь.")
                .font(.system(size: 16))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 28)
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
                Text(title)
                    .font(Face.display(26, .medium))
                    .foregroundStyle(.marbleFill)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if limit == 2 {
                    Text("Можно выбрать до двух")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ash)
                }
                ForEach(options, id: \.self) { option in
                    chip(option, on: selected.contains(option)) {
                        onTap(option)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private var feelingStep: some View {
        painStep(
            title: "Первые 10 минут после импульса",
            subtitle: "Будь предельно честен перед собой. Что ты чувствовал в тот момент?",
            options: feelingOptions,
            selected: relapseFeelings
        ) { toggle($0, in: &relapseFeelings, limit: nil) }
        extra: {
            ownField("Свой вариант", text: $customFeeling, multiline: false, field: .feeling)
        }
    }

    private var lossStep: some View {
        painStep(
            title: "Цена минутной слабости",
            subtitle: "Чем ты уже заплатил за экранный фастфуд за последние 12 месяцев?",
            options: lossOptions,
            selected: yearLosses
        ) { toggle($0, in: &yearLosses, limit: nil) }
    }

    private var futureStep: some View {
        painStep(
            title: "Кем ты станешь через год",
            subtitle: "Представь год без срывов. Каким ты себя видишь?",
            options: futureOptions,
            selected: futureChoice.map { [$0] } ?? []
        ) { toggleSingle($0, into: &futureChoice) }
        extra: {
            Text("Или напиши своими словами...")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
            ownField("", text: $futureNote, multiline: true, field: .future)
        }
    }

    private func painStep(
        title: String,
        subtitle: String,
        options: [String],
        selected: [String],
        onTap: @escaping (String) -> Void,
        @ViewBuilder extra: () -> some View = { EmptyView() }
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(Face.display(26, .medium))
                    .foregroundStyle(.marbleFill)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(options, id: \.self) { option in
                    chip(option, on: selected.contains(option)) {
                        focusedField = nil
                        onTap(option)
                    }
                }
                extra()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // Касание пустого места убирает клавиатуру. Жест на самой прокрутке:
        // слой под ней касаний не получает. Варианты и поле — дочерние,
        // их собственные нажатия срабатывают раньше.
        .onTapGesture { focusedField = nil }
    }

    /// Многострочное поле перехватывает «Ввод» под перенос строки, и
    /// клавиатуру было нечем убрать. Здесь «Ввод» — это «Готово».
    private func ownField(_ placeholder: String, text: Binding<String>, multiline: Bool, field: Field) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(multiline ? 3...6 : 1...2)
            .font(.system(size: 16))
            .foregroundStyle(Palette.marbleHigh)
            .focused($focusedField, equals: field)
            .submitLabel(.done)
            .onChange(of: text.wrappedValue) { _, value in
                guard value.contains("\n") else { return }
                text.wrappedValue = value.replacingOccurrences(of: "\n", with: "")
                focusedField = nil
            }
            .padding(14)
            .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(focusedField == field ? Palette.gold : Palette.vein, lineWidth: 1)
            }
    }

    private var dayQuestion: some View {
        question(
            title: "Сколько дней чистоты ты ставишь своей первой целью?",
            options: dayOptions.map { "\($0) дней" },
            selected: targetDays.map { ["\($0) дней"] } ?? [],
            limit: 1
        ) { title in
            if let days = dayOptions.first(where: { "\($0) дней" == title }) {
                targetDays = days
                Haptics.selection()
            }
        }
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

    /// Та же кнопка, что в первом опросе: два опроса подряд не должны
    /// выглядеть как два разных приложения.
    private var footer: some View {
        Button(buttonTitle, action: advance)
            .buttonStyle(EngravedButton())
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.35)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .padding(.top, 8)
    }

    private var buttonTitle: String {
        if page == 0 { return "НАЧАТЬ ДИАГНОСТИКУ" }
        if page == contractPage { return "ЗАФИКСИРОВАТЬ ЭТОТ ДОГОВОР" }
        if page == finale { return "ВОЙТИ В ПРИЛОЖЕНИЕ" }
        return "ДАЛЕЕ"
    }

    private var canAdvance: Bool {
        switch page {
        case 0: true
        case 1: duration != nil
        case 2: !triggers.isEmpty
        case 3: !costs.isEmpty
        case 4: pastRecord != nil
        case 5: !goals.isEmpty
        case 6: !relapseFeelings.isEmpty || !customFeeling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 7: !yearLosses.isEmpty
        case 8: futureChoice != nil || !futureNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 9: targetDays != nil
        case finale: generated
        default: false
        }
    }

    private func advance() {
        if page == finale {
            showDecision = true
            return
        }
        if page == contractPage {
            saveContract()
        }
        go(by: 1)
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

    private func saveContract() {
        var feelings = relapseFeelings
        let own = customFeeling.trimmingCharacters(in: .whitespacesAndNewlines)
        if !own.isEmpty { feelings.append(own) }
        let written = futureNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let future = written.isEmpty ? (futureChoice ?? "") : written
        manifest.saveManifest(
            postRelapse: feelings,
            losses: yearLosses,
            vision: future,
            notes: own.isEmpty ? nil : own,
            journal: journal
        )
    }

    private func saveAndEnter() {
        guard let duration, let pastRecord, let targetDays else { return }
        saveContract()
        let note = """
        #ТочкаА #Манифест
        Я начинаю свой путь освобождения. Вот моя честная диагностика на старте:

        ⏳ Стаж зависимости: \(duration)
        ⚠️ Мои главные триггеры: \(triggers.joined(separator: ", "))
        🛑 Что привычка отнимает у меня: \(costs.joined(separator: ", "))
        🏆 Прошлый рекорд воздержания: \(pastRecord)
        🎯 Моя главная цель (Точка Б): \(goals.joined(separator: ", "))
        🔥 Первая планка: \(targetDays) дней чистоты подряд

        Я фиксирую это здесь, чтобы перечитывать эту запись в моменты слабости и помнить, почему я начал.
        """
        let fullNote = (manifest.currentManifest?.journalText ?? "") + "\n\n" + note
        journal.upsertManifest(fullNote)
        streak.setGoal(targetDays)
        let prompt = JournalEntry.manifestBadge
        Task {
            await backend.saveJournal(mood: nil, urge: nil, prompt: prompt, note: fullNote, into: journal)
        }
        onFinish()
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Face.display(16, .medium))
                    .foregroundStyle(on ? Palette.onGold : Palette.marbleHigh)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Palette.onGold : Palette.ash)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(on ? AnyShapeStyle(.goldSurface) : AnyShapeStyle(Palette.basalt), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? Color.clear : Palette.vein, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleSingle(_ option: String, into value: inout String?) {
        value = option
        Haptics.selection()
    }

    private func toggle(_ option: String, in list: inout [String], limit: Int?) {
        if let index = list.firstIndex(of: option) {
            list.remove(at: index)
        } else if let limit, list.count >= limit {
            return
        } else {
            list.append(option)
        }
        Haptics.selection()
    }
}
