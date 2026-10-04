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
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var openedDay: JourneyDay?

    private var currentDay: Int {
        min(max(streak.currentStreak, 1), JourneyLibrary.totalDays)
    }

    var body: some View {
        localBody
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
        .navigationDestination(item: $openedDay) { day in
            JourneyDayDetailView(day: day)
        }
    }

    private var currentDayCard: some View {
        let day = JourneyLibrary.all.first { $0.day == currentDay } ?? JourneyLibrary.all[0]
        return Button {
            open(day)
        } label: {
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
                    if day.day > 7 && !subscriptions.isPro {
                        ProLockBadge()
                    }
                    Text("Изучить")
                    Image(systemName: "arrow.right")
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
        .buttonStyle(.plain)
    }

    private func dayRow(_ day: JourneyDay) -> some View {
        let isUnlocked = day.day <= currentDay
        return Group {
            if isUnlocked {
                Button {
                    open(day)
                } label: {
                    dayRowContent(day, locked: false, pro: day.day > 7 && !subscriptions.isPro)
                }
                .buttonStyle(.plain)
            } else {
                dayRowContent(day, locked: true)
            }
        }
    }

    private func open(_ day: JourneyDay) {
        let reason = "Доступ ко всей программе восстановления после 7 дней открывается в Pro"
        if day.day <= 7 {
            openedDay = day
        } else {
            subscriptions.checkProAccess(for: reason) { openedDay = day }
        }
    }

    private func dayRowContent(_ day: JourneyDay, locked: Bool, pro: Bool = false) -> some View {
        HStack(spacing: 14) {
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

            if locked {
                Text("через \(day.day - currentDay) дн.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.ash)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.vein.opacity(0.5), in: .capsule)
            } else {
                if pro { ProLockBadge() }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ash)
            }
        }
        .padding(14)
        .cardSurface()
        .opacity(locked ? 0.55 : 1)
    }
}

struct JourneyDayDetailView: View {

    let day: JourneyDay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(day.phaseTitle)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.gold)

                Text("День \(day.day)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ash)

                Text(day.title)
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)

                section("Биохимия", symbol: "brain.head.profile", tint: Color(hex: 0x3DDCB0), text: day.biochemistry)
                section("В реальности", symbol: "bolt.heart.fill", tint: Color(hex: 0xFF6B3D), text: day.realFeel)
                section("Ловушка дня", symbol: "exclamationmark.shield.fill", tint: Color(hex: 0xF0BC4F), text: day.trapWarning)
                section("Действие", symbol: "checkmark.seal.fill", tint: Color(hex: 0x3DDC97), text: day.tacticalAction)
            }
            .padding(20)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, symbol: String, tint: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Palette.marble)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardSurface()
    }
}
