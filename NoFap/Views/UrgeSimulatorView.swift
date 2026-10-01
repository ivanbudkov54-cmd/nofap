//
//  UrgeSimulatorView.swift
//  NoFap
//
//  Вкладка «Urge Simulator» — интерактивный квест по сценариям срыва.
//  Тренирует распознавание рационализаций до того, как они превратились
//  в действие: деструктивный выбор показывает всю цепочку последствий,
//  верный выбор — что именно укрепилось.
//

import SwiftUI

struct UrgeSimulatorView: View {

    @Environment(Backend.self) private var backend
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var opened: UrgeScenario?

    var body: some View {
        let remote = backend.articles(tab: "urge_simulator")
        if remote.isEmpty {
            localBody
        } else {
            RemoteArticleList(articles: remote, proReason: "Разблокируй готовые сценарии предотвращения срывов")
        }
    }

    private var localBody: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                VStack(spacing: 12) {
                    ForEach(UrgeSimulatorLibrary.all) { scenario in
                        Button {
                            subscriptions.checkProAccess(for: "Разблокируй готовые сценарии предотвращения срывов") {
                                opened = scenario
                            }
                        } label: {
                            scenarioRow(scenario)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .navigationDestination(item: $opened) { scenario in
            UrgeScenarioPlayerView(scenario: scenario)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Выбери сценарий")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Text("Пройди ситуацию до конца и увидь, к чему реально ведёт каждый выбор.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scenarioRow(_ scenario: UrgeScenario) -> some View {
        HStack(spacing: 14) {
            Image(systemName: scenario.icon)
                .font(.system(size: 18))
                .foregroundStyle(.goldFill)
                .frame(width: 42, height: 42)
                .background(Palette.gold.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.leading)
                Text(scenario.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)
                    .lineLimit(2)
            }

            if !subscriptions.isPro {
                ProLockBadge()
            }
            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ash)
        }
        .padding(16)
        .cardSurface()
    }
}

struct UrgeScenarioPlayerView: View {

    let scenario: UrgeScenario

    @State private var currentStepId: String
    @State private var result: UrgeChoice?
    @Environment(\.dismiss) private var dismiss

    init(scenario: UrgeScenario) {
        self.scenario = scenario
        _currentStepId = State(initialValue: scenario.startStepId)
    }

    private var stepsById: [String: UrgeStep] { scenario.stepsById }
    private var currentStep: UrgeStep? { stepsById[currentStepId] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let result {
                    outcomeView(result)
                } else if let step = currentStep {
                    stepView(step)
                }
            }
            .padding(20)
            .animation(.snappy(duration: 0.25), value: currentStepId)
            .animation(.snappy(duration: 0.25), value: result)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationTitle(scenario.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepView(_ step: UrgeStep) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(step.text)
                .font(.system(size: 16))
                .foregroundStyle(Palette.marble)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(step.choices) { choice in
                    Button {
                        choose(choice)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(choice.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Palette.marbleHigh)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ash)
                        }
                        .padding(14)
                        .cardSurface()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func choose(_ choice: UrgeChoice) {
        if let next = choice.nextStepId {
            currentStepId = next
        } else {
            result = choice
        }
    }

    private func outcomeView(_ choice: UrgeChoice) -> some View {
        let tint: Color = choice.isFailure ? Color(hex: 0xE05A45) : Palette.gold

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: choice.isFailure ? "xmark.octagon.fill" : "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
                Text(choice.isFailure ? "Срыв" : "Стрик сохранён")
                    .font(Face.display(20, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
            }

            Text(choice.outcome ?? "")
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(tint.opacity(0.08), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.3), lineWidth: 1)
                }

            VStack(spacing: 10) {
                Button("Пройти заново") {
                    currentStepId = scenario.startStepId
                    result = nil
                }
                .buttonStyle(GoldButton())

                Button("Выбрать другой сценарий") { dismiss() }
                    .buttonStyle(StoneButton())
            }
            .padding(.top, 4)
        }
    }
}
