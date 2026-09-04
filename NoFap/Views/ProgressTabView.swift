//
//  ProgressTabView.swift
//  NoFap
//
//  Прогресс на реальных данных из StreakManager.history — не заглушка.
//  Название не ProgressView, чтобы не столкнуться с одноимённым типом SwiftUI.
//

import SwiftUI

struct ProgressTabView: View {

    @Environment(StreakManager.self) private var streak

    private enum Span: String, CaseIterable { case day = "День", week = "Неделя", month = "Месяц", year = "Год" }

    @State private var span: Span = .month

    /// Неделя считается с понедельника независимо от региона устройства.
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        return cal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                whyCard
                picker

                switch span {
                case .day:   DaySpan(streak: streak)
                case .week:  WeekSpan(streak: streak, calendar: isoCalendar)
                case .month: MonthSpan(streak: streak, calendar: isoCalendar)
                case .year:  YearSpan(streak: streak, calendar: isoCalendar)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Text("Твой прогресс")
                .font(Face.display(26, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Spacer()
        }
        .padding(.top, 6)
    }

    private var whyCard: some View {
        NavigationLink {
            WhyView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.goldFill)
                    .frame(width: 34, height: 34)
                    .background(Palette.gold.opacity(0.12), in: .circle)

                Text("Зачем ты это делаешь")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.marbleHigh)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ash)
            }
            .padding(16)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private var picker: some View {
        HStack(spacing: 4) {
            ForEach(Span.allCases, id: \.self) { item in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { span = item }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 14, weight: span == item ? .semibold : .regular))
                        .foregroundStyle(span == item ? Color(hex: 0x1A1405) : Palette.ash)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if span == item {
                                Capsule().fill(.goldFill)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(Palette.basalt, in: .capsule)
        .overlay { Capsule().strokeBorder(Palette.vein, lineWidth: 1) }
    }
}

// MARK: - День

private struct DaySpan: View {
    let streak: StreakManager

    private var recent: [(key: String, clean: Bool)] {
        streak.history
            .sorted { $0.key > $1.key }
            .prefix(6)
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Eyebrow(text: "сегодня")
                Text(streak.hasCheckedInToday
                     ? (streak.status(on: Date()) == true ? "Отмечено: чисто" : "Отмечено: был срыв")
                     : "Ещё не отмечено")
                    .font(Face.display(20, .medium))
                    .foregroundStyle(Palette.marbleHigh)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .cardSurface()

            if !recent.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Text(Self.label(for: entry.key))
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.marble)
                            Spacer()
                            Text(entry.clean ? "чисто" : "срыв")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(entry.clean ? .goldFill : LinearGradient(colors: [Palette.ash], startPoint: .top, endPoint: .bottom))
                        }
                        .padding(.vertical, 12)

                        if index < recent.count - 1 {
                            Divider().overlay(Palette.vein)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .cardSurface()
            }
        }
    }

    private static func label(for key: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key) else { return key }
        if Calendar.current.isDateInToday(date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        let out = DateFormatter()
        out.dateFormat = "d MMMM"
        out.locale = Locale(identifier: "ru_RU")
        return out.string(from: date)
    }
}

// MARK: - Неделя

private struct WeekSpan: View {
    let streak: StreakManager
    let calendar: Calendar

    private var days: [Date] {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let mondayIndex = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -mondayIndex, to: calendar.startOfDay(for: today))!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: monday)! }
    }

    private var cleanCount: Int {
        days.filter { streak.status(on: $0) == true }.count
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 8) {
                        Text(Self.weekdayLetter(day))
                            .font(Face.display(11, .semibold))
                            .foregroundStyle(Palette.ash)
                        DayMark(status: streak.status(on: day),
                                isToday: calendar.isDateInToday(day),
                                isFuture: day > Date(),
                                number: calendar.component(.day, from: day))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("\(cleanCount) из 7 дней чисто на этой неделе")
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .cardSurface()
        }
    }

    private static func weekdayLetter(_ date: Date) -> String {
        let names = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        return names[(weekday + 5) % 7]
    }
}

// MARK: - Месяц

private struct MonthSpan: View {
    let streak: StreakManager
    let calendar: Calendar

    @State private var showGoalEditor = false
    @State private var showPartner = false
    @State private var goalDraft = 21

    private var monthDate: Date { Date() }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthDate)!.count
    }

    private var firstOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
    }

    /// Пустых ячеек перед 1-м числом, чтобы сетка встала под «Пн Вт Ср …».
    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return (weekday + 5) % 7
    }

    private var cleanThisMonth: Int {
        (1...daysInMonth).filter { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { return false }
            return streak.status(on: date) == true
        }.count
    }

    private var elapsedDays: Int {
        min(calendar.component(.day, from: Date()), daysInMonth)
    }

    private var percentClean: Int {
        elapsedDays == 0 ? 0 : Int((Double(cleanThisMonth) / Double(elapsedDays) * 100).rounded())
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 18) {
            ring
            calendarCard
            statsRow
        }
    }

    private var ring: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                Eyebrow(text: "свобода в этом месяце")
                    .padding(.top, 18)

                // Фото от края до края — карточка заканчивается ровно там,
                // где заканчивается сама картинка, без отступа снизу.
                GeometryReader { geo in
                    let w = geo.size.width

                    ZStack {
                        Image("SisyphusPhoto")
                            .resizable()
                            .scaledToFit()
                            .frame(width: w)

                        // Центр валуна — константы вымерены по фото. Резкая
                        // тень — отдельный тёмный дубликат текста со сдвигом,
                        // а не blur: так цифра выглядит объёмной, лежащей на камне.
                        VStack(spacing: 0) {
                            ZStack {
                                // 1. Источник свечения — самый нижний слой, его
                                //    ореол должен быть виден вокруг всей цифры.
                                Text("\(streak.currentStreak)")
                                    .font(Face.display(w * 0.14, .semibold))
                                    .foregroundStyle(.goldFill)
                                    .shadow(color: Palette.goldLight.opacity(0.8), radius: 7)
                                    .shadow(color: Palette.gold.opacity(0.5), radius: 13)

                                // 2. Резкая тень со сдвигом — без размытия,
                                //    ширина сдвига как в исходной версии.
                                Text("\(streak.currentStreak)")
                                    .font(Face.display(w * 0.14, .semibold))
                                    .foregroundStyle(.black.opacity(0.7))
                                    .offset(x: w * 0.012, y: w * 0.012 * 1.4)

                                // 3. Чистая цифра поверх всего — перекрывает тень
                                //    везде, кроме тонкого сдвинутого края снизу-
                                //    справа, поэтому свечение не гасит тень.
                                Text("\(streak.currentStreak)")
                                    .font(Face.display(w * 0.14, .semibold))
                                    .foregroundStyle(.goldFill)
                                    .contentTransition(.numericText())
                            }

                            // Личная цель, не календарный месяц — тап открывает
                            // редактор, чтобы её можно было менять не только
                            // при онбординге.
                            Button {
                                goalDraft = streak.personalGoalDays
                                showGoalEditor = true
                            } label: {
                                Text("из \(streak.personalGoalDays) дней")
                                    .font(Face.display(w * 0.034))
                                    .foregroundStyle(Palette.marbleHigh)
                                    .shadow(color: Palette.goldLight.opacity(0.5), radius: 4)
                                    .underline()
                            }
                        }
                        .position(x: w * 0.70, y: w * (515.0 / 493.0) * 0.354)
                    }
                }
                .aspectRatio(493.0 / 515.0, contentMode: .fit)
            }
            .clipShape(.rect(cornerRadius: 18))
            .cardSurface()
            // Бейдж — поверх границы этой карточки, не всего экрана: он
            // рисуется после .clipShape, поэтому не обрезается скруглением.
            .overlay(alignment: .bottomLeading) {
                PartnerBadge(width: 130)
                    .contentShape(.rect)
                    .onTapGesture { showPartner = true }
            }

            // Подпись — снаружи карточки, не часть композиции с фото.
            Text("Каждый день воздержания делает тебя сильнее.")
                .font(Face.display(14))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
        }
        // Лист, а не NavigationLink: экран напарника — отдельная вкладка,
        // и пушить его копию внутрь стека «Прогресс» значило бы держать
        // два источника правды.
        .sheet(isPresented: $showPartner) {
            NavigationStack { PartnerView() }
        }
        .sheet(isPresented: $showGoalEditor) {
            VStack(spacing: 24) {
                GoalPicker(selected: $goalDraft)

                Button("Сохранить") {
                    streak.setGoal(goalDraft)
                    showGoalEditor = false
                }
                .buttonStyle(GoldButton())
            }
            .padding(24)
            .presentationDetents([.height(420)])
            .presentationBackground(Palette.obsidian)
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 14) {
            HStack {
                Eyebrow(text: "календарь")
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(["ПН","ВТ","СР","ЧТ","ПТ","СБ","ВС"], id: \.self) { letter in
                    Text(letter)
                        .font(Face.display(10, .semibold))
                        .foregroundStyle(Palette.ash)
                }

                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 30) }

                ForEach(1...daysInMonth, id: \.self) { day in
                    let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
                    DayMark(status: streak.status(on: date),
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date(),
                            number: day)
                }
            }
        }
        .padding(16)
        .cardSurface()
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: "\(streak.currentStreak)", label: "текущий\nстрик")
            divider
            stat(value: "\(streak.bestStreak)", label: "лучший\nстрик")
            divider
            stat(value: "\(percentClean)%", label: "дней\nбез срывов")
        }
        .padding(.vertical, 18)
        .cardSurface()
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(Face.display(24, .semibold))
                .foregroundStyle(.goldFill)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Palette.vein).frame(width: 1, height: 38)
    }
}

// MARK: - Год

private struct YearSpan: View {
    let streak: StreakManager
    let calendar: Calendar

    private var months: [(name: String, clean: Int, total: Int)] {
        let year = calendar.component(.year, from: Date())
        let today = Date()
        return (1...12).compactMap { month -> (String, Int, Int)? in
            var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
            guard let first = calendar.date(from: comps) else { return nil }
            guard first <= today || calendar.isDate(first, equalTo: today, toGranularity: .month) else { return nil }

            let daysInMonth = calendar.range(of: .day, in: .month, for: first)!.count
            let isCurrent = calendar.isDate(first, equalTo: today, toGranularity: .month)
            let elapsed = isCurrent ? calendar.component(.day, from: today) : daysInMonth
            let clean = (1...elapsed).filter { day in
                let date = calendar.date(byAdding: .day, value: day - 1, to: first)!
                return streak.status(on: date) == true
            }.count

            let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "LLLL"
            return (f.string(from: first).capitalized, clean, elapsed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                HStack {
                    Text(month.name)
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.marbleHigh)

                    Spacer()

                    GeometryReader { geo in
                        Capsule().fill(Palette.vein)
                            .overlay(alignment: .leading) {
                                Capsule().fill(.goldFill)
                                    .frame(width: month.total == 0 ? 0 : geo.size.width * CGFloat(month.clean) / CGFloat(month.total))
                            }
                    }
                    .frame(width: 90, height: 6)

                    Text("\(month.clean)/\(month.total)")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ash)
                        .frame(width: 46, alignment: .trailing)
                }
                .padding(.vertical, 13)

                if index < months.count - 1 {
                    Divider().overlay(Palette.vein)
                }
            }
        }
        .padding(.horizontal, 16)
        .cardSurface()
    }
}

// MARK: - Общая ячейка дня

private struct DayMark: View {
    let status: Bool?
    let isToday: Bool
    let isFuture: Bool
    let number: Int

    var body: some View {
        ZStack {
            if status == true {
                Circle().fill(Palette.gold.opacity(0.16))
                Circle().strokeBorder(Palette.gold, lineWidth: 1.4)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.goldFill)
            } else if isToday {
                Circle().strokeBorder(Palette.gold, lineWidth: 1.4)
                Text("\(number)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.gold)
            } else if status == false {
                Circle().strokeBorder(Palette.vein, lineWidth: 1.2)
                Text("\(number)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.ash)
            } else {
                Text("\(number)")
                    .font(.system(size: 12))
                    .foregroundStyle(isFuture ? Palette.ash.opacity(0.5) : Palette.ash)
            }
        }
        .frame(height: 30)
    }
}
