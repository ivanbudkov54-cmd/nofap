//
//  MyJourneyView.swift
//  NoFap
//
//  Вкладка «My Journey» — drip-контент по дням стрика. Текущий и прошедшие
//  дни доступны для чтения, будущие показаны заблокированными с подсказкой,
//  через сколько дней откроются.
//

import SwiftUI

struct MyJourneyView: View {

    @Environment(StreakManager.self) private var streak
    @Environment(PremiumStore.self) private var premium
    @Environment(CloudSync.self) private var cloud

    @State private var showPaywall = false

    private var currentDay: Int {
        min(max(streak.currentStreak, 1), JourneyLibrary.totalDays)
    }

    private enum Access: Equatable {
        case open
        case inDays(Int)    // откроется по мере стрика
        case premium        // первая неделя пройдена, дальше — подписка
    }

    /// Premium проверяется первым: без подписки дни после недели заперты
    /// независимо от стрика, и честнее сразу сказать почему.
    private func access(_ day: JourneyDay) -> Access {
        if day.day > PremiumStore.freeJourneyDays && !premium.isPremium { return .premium }
        if day.day > currentDay { return .inDays(day.day - currentDay) }
        return .open
    }

    /// Если на сервере есть статьи для этой вкладки — показываем их,
    /// иначе встроенную программу по дням.
    var body: some View {
        let remote = cloud.articles(tab: "journey")
        if remote.isEmpty {
            localBody
        } else {
            RemoteArticleList(articles: remote)
        }
    }

    private var localBody: some View {
        ScrollView {
            VStack(spacing: 14) {
                currentDayCard

                VStack(spacing: 10) {
                    ForEach(JourneyLibrary.all) { day in
                        dayRow(day)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    @ViewBuilder
    private var currentDayCard: some View {
        let day = JourneyLibrary.all.first { $0.day == currentDay } ?? JourneyLibrary.all[0]
        if access(day) == .premium {
            Button { showPaywall = true } label: {
                currentDayCardContent(day, action: "Открыть с Premium", symbol: "lock.open.fill")
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                JourneyDayDetailView(day: day)
            } label: {
                currentDayCardContent(day, action: "Изучить", symbol: "arrow.right")
            }
            .buttonStyle(.plain)
        }
    }

    private func currentDayCardContent(_ day: JourneyDay, action: LocalizedStringResource, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "твой день", color: Palette.gold)

            Text("День \(currentDay) из \(JourneyLibrary.totalDays)")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)

            Text(day.title)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(action)
                Image(systemName: symbol)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(hex: 0x1A1405))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(.goldFill))
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
    }

    @ViewBuilder
    private func dayRow(_ day: JourneyDay) -> some View {
        switch access(day) {
        case .open:
            NavigationLink {
                JourneyDayDetailView(day: day)
            } label: {
                dayRowContent(day, access: .open)
            }
            .buttonStyle(.plain)
        case .premium:
            Button { showPaywall = true } label: {
                dayRowContent(day, access: .premium)
            }
            .buttonStyle(.plain)
        case .inDays(let days):
            dayRowContent(day, access: .inDays(days))
        }
    }

    private func dayRowContent(_ day: JourneyDay, access: Access) -> some View {
        let locked = access != .open
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(locked ? Palette.vein.opacity(0.5) : Palette.gold.opacity(0.15))
                    .frame(width: 40, height: 40)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ash)
                } else {
                    Text("\(day.day)")
                        .font(Face.display(13, .semibold))
                        .foregroundStyle(Palette.gold)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("День \(day.day)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(locked ? Palette.ash : Palette.gold)
                Text(day.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(locked ? Palette.ash : Palette.marbleHigh)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            switch access {
            case .open:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ash)
            case .inDays(let days):
                Text("через \(days) дн.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.ash)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.vein.opacity(0.5), in: .capsule)
            case .premium:
                Text("Premium")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.goldFill))
            }
        }
        .padding(14)
        .cardSurface()
        // Premium-строки не гасим так сильно: они кликабельны и ведут
        // к подписке, в отличие от дней, до которых просто не дорос стрик.
        .opacity(access == .open ? 1 : (access == .premium ? 0.8 : 0.55))
    }
}

struct JourneyDayDetailView: View {

    let day: JourneyDay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(verbatim: day.phase, color: Palette.gold)

                HStack(spacing: 8) {
                    Text("День \(day.day)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ash)
                    Text(day.badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Palette.gold.opacity(0.12), in: .capsule)
                }

                Text(day.title)
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                section("Что происходит", symbol: "brain.head.profile", text: day.insight)
                section("Что можешь заметить", symbol: "eye", text: day.feel)
                section("Ловушка дня", symbol: "exclamationmark.shield", text: day.trap)
                section("Действие на сегодня", symbol: "checkmark.seal", text: day.action, highlighted: true)

                // Статья дня — +20 XP аватару, один раз.
                ArticleStudiedBar(articleID: "journey_day_\(day.day)", isScience: false)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Все блоки в одной золото-мраморной гамме; действие выделено — это
    /// то, ради чего человек открыл день.
    private func section(_ title: LocalizedStringResource, symbol: String, text: String,
                         highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(highlighted ? Palette.gold : Palette.marble)
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Palette.marbleHigh.opacity(0.92))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(highlighted ? Palette.gold.opacity(0.08) : Palette.basalt, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(highlighted ? Palette.gold.opacity(0.4) : Palette.vein, lineWidth: 1)
        }
    }
}
