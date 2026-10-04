//
//  SisyphusStreakCard.swift
//  NoFap
//
//  Главная карточка стрика: Сизиф катит валун, на камне — число дней и
//  личная цель. Вокруг — напарник (большой значок в левом углу) и сквад
//  (плашки на картинке). Раньше жила на «Прогрессе» → «Месяц», теперь —
//  на главном экране вместо «Твой стрик» и «Свободен от».
//

import SwiftUI

struct SisyphusStreakCard: View {

    @Environment(StreakManager.self) private var streak
    @Environment(SquadManager.self) private var squad

    @State private var showGoalEditor = false
    @State private var showGoalLocked = false
    @State private var showPartner = false
    @State private var showSquad = false
    @State private var goalDraft = 21
    @State private var pulse = false

    var body: some View {
        // Без заголовка: на главном картинка говорит сама за себя, а
        // кнопкам внизу нужно место.
        VStack(spacing: 8) {
            VStack(spacing: 0) {
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
                            .scaleEffect(pulse ? 1.25 : 1)
                            .sensoryFeedback(.success, trigger: streak.currentStreak)
                            .onChange(of: streak.currentStreak) { _, _ in
                                // Мягкий «вдох-выдох» цифры при новом дне.
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { pulse = true }
                                withAnimation(.easeInOut(duration: 0.6).delay(0.25)) { pulse = false }
                            }

                            // Личная цель, не календарный месяц. Тап открывает
                            // редактор, только пока цель не в процессе, — иначе
                            // объясняет, когда её можно будет сменить.
                            Button {
                                if streak.canChangeGoal {
                                    goalDraft = streak.personalGoalDays
                                    showGoalEditor = true
                                } else {
                                    showGoalLocked = true
                                }
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
            // Бейджи — поверх границы этой карточки, не всего экрана: они
            // рисуются после .clipShape, поэтому не обрезаются скруглением.
            .overlay(alignment: .bottomLeading) {
                PartnerBadge(width: 130)
                    .contentShape(.rect)
                    .onTapGesture { showPartner = true }
            }
            .overlay {
                SquadOnImage { showPartner = true }
            }

            // Пустых мест на картинке нет — позвать людей отсюда можно
            // одной скромной кнопкой, пока в скваде есть свободные места.
            if squad.freeSlots > 0 {
                Button { showSquad = true } label: {
                    Label("Позвать в сквад", systemImage: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.goldFill)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.4), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                // Посередине между картинкой и цитатой под ней.
                .padding(.top, 11)
            }
        }
        // Лист, а не NavigationLink: экран напарника — отдельная вкладка,
        // держать его копию в другом стеке значило бы два источника правды.
        .sheet(isPresented: $showPartner) {
            NavigationStack { PartnerView() }
        }
        // Сразу сквад, без экрана напарника сверху — иначе до приглашения
        // пришлось бы листать.
        .sheet(isPresented: $showSquad) {
            SquadSheet()
        }
        .alert("Цель уже идёт", isPresented: $showGoalLocked) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Ты поставил себе \(streak.personalGoalDays.daysCount) — дойди до них. Новую цель можно выбрать, когда возьмёшь эту.")
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
}

// MARK: - Лист сквада

/// Лист ровно по высоте содержимого: он поднимается снизу только насколько
/// нужно, и кнопки оказываются в нижней половине экрана — под большим
/// пальцем, а не у самого верха.
struct SquadSheet: View {

    @State private var contentHeight: CGFloat = 560

    var body: some View {
        NavigationStack {
            ScrollView {
                SquadSection()
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        contentHeight = $0
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Palette.obsidian.ignoresSafeArea())
        }
        .presentationDetents([.height(contentHeight), .large])
        .presentationDragIndicator(.visible)
    }
}
