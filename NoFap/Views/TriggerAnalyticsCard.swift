//
//  TriggerAnalyticsCard.swift
//  NoFap
//
//  Карточка «Что тебя цепляет» на вкладке прогресса. Premium-функция:
//  без подписки видно, сколько отметок уже накопилось, но не сам разбор.
//

import SwiftUI

struct TriggerAnalyticsCard: View {

    @Environment(CheckInManager.self) private var checkIns
    @Environment(PremiumStore.self) private var premium
    @Environment(ReminderManager.self) private var reminder

    /// SOS-лог не наблюдаемый — перечитываем при каждом показе вкладки.
    @State private var sos: [TriggerEntry] = []
    @State private var showPaywall = false

    private var insights: TriggerInsights {
        TriggerInsights(sos: sos, checkIns: checkIns.entries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "аналитика триггеров", color: Palette.gold)
                Text("Что тебя цепляет")
                    .font(Face.display(20, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
            }

            if !premium.isPremium {
                locked
            } else if !insights.hasEnoughData {
                notEnoughData
            } else {
                content(insights)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
        .onAppear { sos = TriggerLog.entries() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: - Без подписки

    private var locked: some View {
        let marks = insights.totalMarks
        return VStack(alignment: .leading, spacing: 16) {
            Text(marks > 0
                 ? "Отметок триггеров у тебя уже: \(marks). Посмотри, что за ними стоит: когда тянет чаще и что этому предшествует."
                 : "Отмечай триггеры в SOS и экспресс-чекине — здесь появится картина: когда тянет чаще и что этому предшествует.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)

            // Превью на выдуманных числах, а не размытые настоящие: так
            // ничего личного не проступает сквозь размытие на чужих глазах.
            VStack(spacing: 10) {
                ForEach([0.9, 0.6, 0.4], id: \.self) { share in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4).fill(Palette.vein).frame(width: 90, height: 10)
                        bar(share: share, emphasized: share == 0.9)
                    }
                }
            }
            .blur(radius: 5)
            .overlay {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.gold)
            }
            .accessibilityHidden(true)

            Button { showPaywall = true } label: {
                HStack(spacing: 6) {
                    Text("Открыть с Premium")
                    Image(systemName: "lock.open.fill")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x1A1405))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(.goldFill))
            }
            .buttonStyle(.plain)
        }
    }

    private var notEnoughData: some View {
        Text("Пока мало данных. Отмечай триггеры в опросе после SOS и в экспресс-чекине — после \(TriggerInsights.minimumMarks) отметок здесь появится картина.")
            .font(.system(size: 14))
            .foregroundStyle(Palette.ash)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Разбор

    private func content(_ insights: TriggerInsights) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let summary = summary(insights) {
                Text(summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if reminder.isPersonalized, let peak = reminder.peakHour {
                Label {
                    Text("Напоминание перенесено на \((peak + 23) % 24):00 — за час до твоего опасного времени.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Palette.gold)
                }
                .font(.system(size: 13))
                .foregroundStyle(Palette.marble)
            }

            section("чаще всего") {
                let top = insights.triggers.prefix(5)
                let most = top.first?.count ?? 1
                VStack(spacing: 12) {
                    ForEach(Array(top)) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(item.key.emoji)  \(item.key.title)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Palette.marble)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Palette.ash)
                            }
                            bar(share: Double(item.count) / Double(most),
                                emphasized: item.key == insights.topTrigger)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("\(item.key.title): \(item.count)"))
                    }
                }
            }

            if insights.sosMoments > 0 {
                section("время суток") {
                    columns(insights.dayParts.map { ($0.key.label, $0.count) },
                            peak: insights.peakDayPart.map { $0.rawValue })
                }
            }

            section("дни недели") {
                columns(insights.weekdays.map { (TriggerInsights.weekdayShort($0.key), $0.count) },
                        peak: insights.peakWeekday)
            }
        }
    }

    private func summary(_ insights: TriggerInsights) -> String? {
        guard let top = insights.topTrigger else { return nil }
        var text = String(localized: "Главный триггер — \(top.title.lowercased()).")
        if let part = insights.peakDayPart {
            text += " " + String(localized: "Чаще всего тянет \(part.phrase)")
            if let day = insights.peakWeekday {
                text += ", " + String(localized: "особенно \(TriggerInsights.weekdayPhrase(day))")
            }
            text += "."
        } else if let day = insights.peakWeekday {
            text += " " + String(localized: "Тяжелее всего \(TriggerInsights.weekdayPhrase(day)).")
        }
        return text
    }

    // MARK: - Элементы графиков

    private func section<Content: View>(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: title)
            content()
        }
    }

    /// Горизонтальная полоса: трек цвета прожилки, заливка золотом.
    /// Пик — полная заливка, остальные приглушены: один цвет, разная сила.
    private func bar(share: Double, emphasized: Bool) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Palette.vein.opacity(0.6))
                RoundedRectangle(cornerRadius: 4)
                    .fill(emphasized ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.gold.opacity(0.45)))
                    .frame(width: max(8, proxy.size.width * share))
            }
        }
        .frame(height: 8)
    }

    /// Вертикальные столбики с подписями снизу. Число — только у пика:
    /// цифра над каждым столбиком превращает график в таблицу.
    private func columns(_ items: [(label: String, count: Int)], peak: Int?) -> some View {
        let most = max(items.map(\.count).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isPeak = index == peak
                VStack(spacing: 6) {
                    Text(isPeak ? "\(item.count)" : " ")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.marbleHigh)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPeak ? AnyShapeStyle(.goldFill)
                              : AnyShapeStyle(Palette.gold.opacity(item.count > 0 ? 0.35 : 0.12)))
                        .frame(height: max(4, 64 * CGFloat(item.count) / CGFloat(most)))
                    Text(item.label)
                        .font(.system(size: 11, weight: isPeak ? .semibold : .regular))
                        .foregroundStyle(isPeak ? Palette.marble : Palette.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(item.label): \(item.count)"))
            }
        }
        .frame(height: 104, alignment: .bottom)
    }
}
