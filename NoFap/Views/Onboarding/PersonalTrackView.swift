//
//  PersonalTrackView.swift
//  NoFap
//
//  Итог опроса: контраст «что забирает / за чем пришёл» и срок первой цели.
//  Ничего не диагностирует — только возвращает человеку его же ответы,
//  собранные вместе. Ради этого контраста опрос и затевался.
//

import SwiftUI

struct PersonalTrackView: View {

    let answers: IntroSurveyAnswers
    let track: PersonalTrack

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "твой трек")

                Text("Вот что ты про себя сказал")
                    .font(Face.display(26, .medium))
                    .foregroundStyle(.marbleFill)
                    .fixedSize(horizontal: false, vertical: true)

                contrast

                goal

                ForEach(track.statements, id: \.self) { line in
                    Text(verbatim: line)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.marble)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .cardSurface()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Контраст

    private var contrast: some View {
        HStack(alignment: .top, spacing: 14) {
            column(title: "забирает сейчас",
                   items: NegativeEffect.allCases.filter(answers.effects.contains).map(\.label),
                   tint: Palette.ash,
                   symbol: "arrow.down.right")

            column(title: "ты пришёл за",
                   items: DesiredOutcome.allCases.filter(answers.outcomes.contains).map(\.label),
                   tint: Palette.gold,
                   symbol: "arrow.up.right")
        }
    }

    /// Маркер — SF Symbol, а не набранное тире: стрелка вниз у того, что
    /// забирает, и вверх у того, за чем пришёл, — это и есть контраст.
    private func column(title: LocalizedStringResource, items: [String], tint: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title, color: tint)

            ForEach(items, id: \.self) { item in
                Label {
                    Text(verbatim: item)
                        .foregroundStyle(tint == Palette.gold ? Palette.marbleHigh : Palette.marble)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                        .imageScale(.small)
                }
                .font(.system(size: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface()
    }

    // MARK: - Срок

    private var goal: some View {
        VStack(spacing: 6) {
            Text("\(track.recommendedGoalDays)")
                .font(Face.display(48, .semibold))
                .foregroundStyle(.goldFill)
                .contentTransition(.numericText())

            Text(verbatim: track.recommendedGoalDays.daysMilestoneWord)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .cardSurface()
    }
}
