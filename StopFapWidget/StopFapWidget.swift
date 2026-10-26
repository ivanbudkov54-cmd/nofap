//
//  StopFapWidget.swift
//  StopFapWidget
//
//  Виджет стрика: Сизиф с валуном и число дней на камне — как карточка на
//  главном. Средний добавляет кнопку SOS, на экране блокировки — кольцо до
//  цели и строка. Данные приложение кладёт в App Group (ShieldShared) и
//  само просит WidgetKit перерисовать виджет после каждой отметки.
//

import SwiftUI
import WidgetKit

// MARK: - Данные

struct StreakEntry: TimelineEntry {
    let date: Date
    let days: Int
    let goal: Int
    let checkedIn: Bool

    var progress: Double { min(Double(days) / Double(max(goal, 1)), 1) }
}

struct StreakProvider: TimelineProvider {

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, days: 12, goal: 21, checkedIn: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    /// Стрик меняется только из приложения, а оно само перезагружает
    /// таймлайн. Сами по себе меняется лишь «отмечался ли сегодня» — в
    /// полночь, поэтому второй снимок ставим на начало следующего дня.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry(at: now), entry(at: midnight)], policy: .after(midnight)))
    }

    private func entry(at date: Date) -> StreakEntry {
        let checked = ShieldShared.lastCheckin.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
        return StreakEntry(date: date, days: ShieldShared.streakDays, goal: ShieldShared.goalDays, checkedIn: checked)
    }
}

// MARK: - Палитра приложения (тёмная тема)

private enum WidgetPalette {
    static let obsidian = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0D / 255)
    static let gold = Color(red: 0xF0 / 255, green: 0xBC / 255, blue: 0x4F / 255)
    static let goldLight = Color(red: 0xF7 / 255, green: 0xCF / 255, blue: 0x7C / 255)
    static let marbleHigh = Color(red: 0xE4 / 255, green: 0xE7 / 255, blue: 0xEF / 255)
    static let ash = Color(red: 0x7A / 255, green: 0x7A / 255, blue: 0x87 / 255)
    static let vein = Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x34 / 255)
    static let garnet = Color(red: 0xE0 / 255, green: 0x52 / 255, blue: 0x4A / 255)
    static let onGold = Color(red: 0x1A / 255, green: 0x14 / 255, blue: 0x05 / 255)

    static var goldFill: LinearGradient {
        LinearGradient(colors: [goldLight, gold], startPoint: .top, endPoint: .bottom)
    }

    static func display(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "Unbounded-Bold" : "Unbounded-Regular", size: size)
    }
}

private func daysWord(_ days: Int) -> String {
    let mod10 = days % 10
    let mod100 = days % 100
    if mod10 == 1 && mod100 != 11 { return "день" }
    if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "дня" }
    return "дней"
}

// MARK: - Сизиф с числом на валуне

/// Фото приближено к валуну и Сизифу: левый нижний склон горы обрезан,
/// чтобы камень с числом стоял ближе к центру виджета. Центр валуна
/// вымерен по фото — те же доли, что в SisyphusStreakCard.
private struct SisyphusStreak: View {
    let days: Int
    let goal: Int

    private static let aspect = 1114.0 / 1066.0
    private static let zoom = 1.22
    /// Точка фото (в долях), которая встаёт в центр виджета.
    private static let focus = CGPoint(x: 0.64, y: 0.47)
    private static let boulder = CGPoint(x: 0.70, y: 0.354)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let imageWidth = w * Self.zoom
            let imageHeight = imageWidth * Self.aspect
            // Слева и снизу фото всегда доходит до края — там гора. Сверху
            // и справа у него прозрачное небо, поэтому туда можно сдвинуть:
            // над камнем останется чёрное поле.
            let x0 = max(w - imageWidth, w / 2 - Self.focus.x * imageWidth)
            let y0 = min(h * 0.12, max(h - imageHeight, h / 2 - Self.focus.y * imageHeight))

            ZStack {
                Image("WidgetSisyphus")
                    .resizable()
                    .frame(width: imageWidth, height: imageHeight)
                    .position(x: x0 + imageWidth / 2, y: y0 + imageHeight / 2)

                VStack(spacing: 1) {
                    ZStack {
                        Text("\(days)")
                            .font(WidgetPalette.display(w * 0.22))
                            .foregroundStyle(.black.opacity(0.7))
                            .offset(x: w * 0.012, y: w * 0.017)
                        Text("\(days)")
                            .font(WidgetPalette.display(w * 0.22))
                            .foregroundStyle(WidgetPalette.goldFill)
                            .shadow(color: WidgetPalette.goldLight.opacity(0.7), radius: 6)
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                    Text("из \(goal)")
                        .font(WidgetPalette.display(w * 0.065, bold: false))
                        .foregroundStyle(WidgetPalette.marbleHigh)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                }
                .frame(width: imageWidth * 0.34)
                .position(x: x0 + Self.boulder.x * imageWidth, y: y0 + Self.boulder.y * imageHeight)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }
}

// MARK: - Размеры

private struct SmallStreakView: View {
    let entry: StreakEntry

    var body: some View {
        SisyphusStreak(days: entry.days, goal: entry.goal)
            .overlay(alignment: .bottomLeading) {
                CheckInLabel(checkedIn: entry.checkedIn)
                    .padding(12)
            }
    }
}

private struct MediumStreakView: View {
    let entry: StreakEntry

    var body: some View {
        HStack(spacing: 0) {
            SisyphusStreak(days: entry.days, goal: entry.goal)
                .frame(width: 150)

            VStack(alignment: .leading, spacing: 8) {
                Text("БЕЗ СРЫВА")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(WidgetPalette.gold)

                Text("\(entry.days) \(daysWord(entry.days))")
                    .font(WidgetPalette.display(20))
                    .foregroundStyle(WidgetPalette.marbleHigh)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(WidgetPalette.vein)
                            Capsule().fill(WidgetPalette.goldFill)
                                .frame(width: max(geo.size.width * entry.progress, 6))
                        }
                    }
                    .frame(height: 5)

                    Text("цель — \(entry.goal) \(daysWord(entry.goal))")
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetPalette.ash)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    CheckInLabel(checkedIn: entry.checkedIn)
                    Spacer(minLength: 0)
                    Link(destination: ShieldShared.sosURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                            Text("SOS")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WidgetPalette.garnet)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(Capsule().strokeBorder(WidgetPalette.garnet, lineWidth: 1.5))
                        .fixedSize()
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
        }
    }
}

private struct CheckInLabel: View {
    let checkedIn: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: checkedIn ? "checkmark.circle.fill" : "circle")
            // Ширина — по самой длинной подписи: значок не прыгает, когда
            // в полночь «Отмечено» сменяется на «Отметься».
            ZStack(alignment: .leading) {
                Text("Отмечено").hidden()
                Text("Отметься").hidden()
                Text(checkedIn ? "Отмечено" : "Отметься")
            }
        }
        .lineLimit(1)
        .fixedSize()
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(checkedIn ? WidgetPalette.gold : WidgetPalette.marbleHigh)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.black.opacity(0.55)))
    }
}

private struct CircularStreakView: View {
    let entry: StreakEntry

    var body: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.days)")
                .font(WidgetPalette.display(16))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

private struct RectangularStreakView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("StopFap")
                .font(.system(size: 13, weight: .semibold))
                .widgetAccentable()
            Text("\(entry.days) \(daysWord(entry.days)) из \(entry.goal)")
                .font(WidgetPalette.display(14))
            Text(entry.checkedIn ? "Сегодня отмечено" : "Отметься сегодня")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumStreakView(entry: entry)
        case .accessoryCircular:
            CircularStreakView(entry: entry)
        case .accessoryRectangular:
            RectangularStreakView(entry: entry)
        case .accessoryInline:
            Text("StopFap · \(entry.days) \(daysWord(entry.days))")
        default:
            SmallStreakView(entry: entry)
        }
    }
}

// MARK: - Виджет

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(WidgetPalette.obsidian, for: .widget)
        }
        .configurationDisplayName("Стрик")
        .description("Дни без срыва, отметка за сегодня и быстрый SOS.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        // Фото Сизифа — от края до края, как на главном.
        .contentMarginsDisabled()
    }
}

@main
struct StopFapWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
    }
}

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, days: 12, goal: 21, checkedIn: true)
}

#Preview(as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, days: 3, goal: 21, checkedIn: false)
}
