//
//  AppTourManager.swift
//  NoFap
//

import SwiftUI
import UIKit

enum AppTourStep: Int, CaseIterable, Identifiable, Hashable {
    case homeTimer
    case homeSOS
    case avatar
    case challenges
    case journal
    case finish

    var id: Int { rawValue }

    var tab: Int? {
        switch self {
        case .homeTimer, .homeSOS: 0
        case .journal: AppRouter.diaryTab
        case .challenges: 3
        case .avatar: 5
        case .finish: nil
        }
    }

    var title: String {
        switch self {
        case .homeTimer: "Твой главный бастион"
        case .homeSOS: "Кнопка паники (SOS)"
        case .avatar: "Твоя трансформация"
        case .challenges: "Испытания воли"
        case .journal: "Твой личный дневник"
        case .finish: "Ты полностью экипирован ⚔️"
        }
    }

    var detail: String {
        switch self {
        case .homeTimer:
            "Здесь тикает твой стрик. Каждый вечер нажимай «Я держусь», подтверждая победу над слабостью. Если сорвешься — 1 раз в месяц доступна заморозка без потери дней."
        case .homeSOS:
            "Если накатила сильная тяга — не думай, сразу жми сюда. Мы включим пошаговую технику заземления и дыхания, чтобы снять импульс за 2 минуты."
        case .avatar:
            "Этот аватар растет вместе с тобой. Каждый день стрика, прочитанная статья и выполненный вызов дают ему силу и мускулы. Прокачай его до ранга Титана."
        case .challenges:
            "Перенаправляй дофамин в реальность: знакомься с девушками, принимай ледяной душ и устраивай цифровой детокс. Закрыл челлендж — сразу получаешь следующий."
        case .journal:
            "Здесь уже сохранена твоя стартовая точка из опроса. Фиксируй мысли, отслеживай триггеры и разбирай сложные дни, чтобы видеть динамику."
        case .finish:
            "Инструменты настроены. Правила ясны. Твой путь к новому себе начинается прямо сейчас."
        }
    }

    /// Пять рабочих шагов, финал считается отдельно.
    var spotlightIndex: Int? {
        self == .finish ? nil : rawValue + 1
    }
}

struct TourFramesKey: PreferenceKey {
    static var defaultValue: [AppTourStep: [CGRect]] = [:]

    static func reduce(value: inout [AppTourStep: [CGRect]], nextValue: () -> [AppTourStep: [CGRect]]) {
        for (step, rects) in nextValue() {
            let visible = rects.filter { $0.width > 2 && $0.height > 2 }
            guard !visible.isEmpty else { continue }
            value[step, default: []].append(contentsOf: visible)
        }
    }
}

enum TourSpaceName {
    static let name = "appTour"
}

extension View {
    func tourTarget(_ step: AppTourStep) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: TourFramesKey.self,
                    value: [step: [geo.frame(in: .named(TourSpaceName.name))]]
                )
            }
        }
    }
}

@MainActor
@Observable
final class AppTourManager {

    private(set) var isTourActive = false
    private(set) var currentStepIndex = 0
    /// false, пока подсказка гаснет или вкладка ещё едет.
    var spotlightVisible = true
    private var advancing = false
    var frames: [AppTourStep: [CGRect]] = [:]

    var step: AppTourStep {
        let steps = AppTourStep.allCases
        return steps[min(currentStepIndex, steps.count - 1)]
    }

    func startTourIfNeeded() {
        let defaults = UserDefaults.standard
        let quizDone = defaults.bool(forKey: "hasCompletedOnboarding")
        let tourDone = defaults.bool(forKey: "hasCompletedAppTour")
        guard quizDone, !tourDone, !isTourActive else { return }
        currentStepIndex = 0
        isTourActive = true
    }

    func nextStep() {
        guard !advancing else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let steps = AppTourStep.allCases
        if currentStepIndex >= steps.count - 1 {
            skipTour()
            return
        }

        let next = steps[currentStepIndex + 1]
        let changesTab = next.tab != nil && next.tab != step.tab
        advancing = true
        withAnimation(.easeInOut(duration: 0.28)) {
            spotlightVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            currentStepIndex += 1
            try? await Task.sleep(for: .milliseconds(changesTab ? 520 : 220))
            withAnimation(.easeInOut(duration: 0.4)) {
                spotlightVisible = true
            }
            advancing = false
        }
    }

    func skipTour() {
        isTourActive = false
        UserDefaults.standard.set(true, forKey: "hasCompletedAppTour")
    }

    func setFrames(_ incoming: [AppTourStep: [CGRect]]) {
        guard !Self.same(frames, incoming) else { return }
        frames = incoming
    }

    private static func same(_ lhs: [AppTourStep: [CGRect]], _ rhs: [AppTourStep: [CGRect]]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (step, rects) in lhs {
            guard let other = rhs[step], other.count == rects.count else { return false }
            for (a, b) in zip(rects, other) where abs(a.minX - b.minX) > 2 || abs(a.minY - b.minY) > 2 || abs(a.width - b.width) > 2 || abs(a.height - b.height) > 2 {
                return false
            }
        }
        return true
    }
}
