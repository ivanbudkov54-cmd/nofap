//
//  WhyView.swift
//  NoFap
//
//  Личные причины — то, к чему возвращаешься в момент тяги, а не статистика.
//  Отдельно от «Прогресса» по смыслу, поэтому не вкладка, а переход с неё.
//

import SwiftUI

/// Разные причины реагируют на один и тот же срыв по-разному, поэтому у
/// каждой свой источник прогресса, а не общий стрик для всех:
/// - `.current` — свежий эффект, который действительно теряется после
///   срыва (энергия, внешний вид, фокус).
/// - `.accumulated` — про характер, а не про текущую полосу: один плохой
///   день не должен обнулять уверенность или ощущение свободы, поэтому
///   считаем от накопленных чистых дней за всё время, а не от streak’а.
/// - `.consistency` — про стабильность в последний месяц, а не про пик:
///   отношения строятся на регулярности, а не на рекорде.
private enum ProgressBasis {
    case current
    case accumulated
    case consistency
}

private struct Reason: Identifiable {
    let id = UUID()
    /// Ключ выбора в UserDefaults. Совпадает с прежним русским заголовком
    /// намеренно: до локализации ключом была сама строка заголовка, и по
    /// этим значениям у людей уже сохранены отмеченные причины.
    let key: String
    let icon: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    var basis: ProgressBasis = .current
}

private let builtInReasons: [Reason] = [
    Reason(key: "Больше энергии", icon: "bolt.fill", title: "Больше энергии", subtitle: "Ты чувствуешь себя живым", basis: .current),
    Reason(key: "Лучший внешний вид", icon: "sparkles", title: "Лучший внешний вид", subtitle: "Тестостерон на максимуме", basis: .current),
    Reason(key: "Уверенность", icon: "checkmark.shield.fill", title: "Уверенность", subtitle: "Ты уважаешь себя", basis: .accumulated),
    Reason(key: "Фокус и продуктивность", icon: "brain.head.profile", title: "Фокус и продуктивность", subtitle: "Меньше тумана в голове", basis: .current),
    Reason(key: "Настоящие отношения", icon: "heart.fill", title: "Настоящие отношения", subtitle: "Ты готов к настоящей любви", basis: .consistency),
    Reason(key: "Свобода от зависимости", icon: "lock.open.fill", title: "Свобода от зависимости", subtitle: "Ты хозяин своих желаний", basis: .accumulated),
]

struct WhyView: View {

    @Environment(StreakManager.self) private var streak
    @Environment(ReasonsStore.self) private var reasons
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAdding = false
    @State private var draft = ""

    private func progress(for basis: ProgressBasis) -> Double {
        guard streak.personalGoalDays > 0 else { return 0 }
        let goal = Double(streak.personalGoalDays)

        switch basis {
        case .current:
            return min(1, Double(streak.currentStreak) / goal)
        case .accumulated:
            // totalCleanDays никогда не обнуляется срывом, в отличие от
            // currentStreak — поэтому один плохой день не роняет в ноль
            // то, что накоплено за всё время.
            return min(1, Double(streak.totalCleanDays) / goal)
        case .consistency:
            return recentConsistency
        }
    }

    /// Доля чистых дней за последние 30 дней истории — не рекорд, а то,
    /// насколько ровно человек держится в последнее время.
    private var recentConsistency: Double {
        let calendar = Calendar.current
        let today = Date()
        let cleanCount = (0..<30).reduce(into: 0) { count, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return }
            if streak.status(on: day) == true { count += 1 }
        }
        return min(1, Double(cleanCount) / 30)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Зачем ты это делаешь?")
                        .font(Face.display(26, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                    Text("Помни свою цель. Возвращайся к ней каждый день.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ash)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    ForEach(Array(builtInReasons.enumerated()), id: \.element.id) { index, reason in
                        row(icon: reason.icon, title: Text(reason.title), subtitle: reason.subtitle, key: reason.key, basis: reason.basis)
                        if index < builtInReasons.count - 1 || !reasons.custom.isEmpty {
                            Divider().overlay(Palette.vein).padding(.leading, 62)
                        }
                    }

                    ForEach(Array(reasons.custom.enumerated()), id: \.element.id) { index, reason in
                        // У своей причины нет категории — берём тот же
                        // источник, что и для «свежих» эффектов по умолчанию.
                        row(icon: "star.fill", title: Text(verbatim: reason.text), subtitle: "Твоя причина",
                            key: reason.key, basis: .current, onDelete: { delete(reason) })
                        if index < reasons.custom.count - 1 {
                            Divider().overlay(Palette.vein).padding(.leading, 62)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .cardSurface()

                Text("«Дисциплина — это мост между целями и достижениями.»")
                    .font(Face.quote(16))
                    .foregroundStyle(Palette.marble.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— Джим Рон")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Palette.gold)
                }
            }
        }
        .alert("Твоя причина", isPresented: $isAdding) {
            TextField("Например: хочу высыпаться", text: $draft)
            Button("Отмена", role: .cancel) { draft = "" }
            Button("Добавить") { add() }
        }
    }

    private func row(icon: String, title: Text, subtitle: LocalizedStringResource, key: String,
                     basis: ProgressBasis, onDelete: (() -> Void)? = nil) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { reasons.toggle(key) }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.goldFill)
                    .frame(width: 34, height: 34)
                    .background(Palette.gold.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(Face.display(16, .medium))
                        .foregroundStyle(Palette.marbleHigh)
                    Text(subtitle)
                        .font(Face.display(13))
                        .foregroundStyle(Palette.ash)
                }

                Spacer()

                if let onDelete {
                    // `.swipeActions` здесь не работал вообще: он живёт только
                    // внутри List, а тут VStack в ScrollView — свои причины
                    // нельзя было удалить никак.
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.ash)
                            .frame(width: 26, height: 26)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }

                // Выбрана ли причина — решает человек. Насколько он к ней
                // продвинулся — показывает кольцо, но по-разному для
                // разных причин (см. ProgressBasis) — бинарной галочкой
                // такое не измерить.
                ring(selected: reasons.isSelected(key), value: progress(for: basis))
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Кольцо рисуется всегда, а анимируется `trim` — при рендере «по
    /// появлению» оно возникало уже дорисованным и ничего не объясняло.
    private func ring(selected: Bool, value: Double) -> some View {
        let shown = selected ? value : 0

        return ZStack {
            Circle()
                .stroke(Palette.vein, lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: shown)
                .stroke(Palette.gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(shown * 100))")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.goldFill)
                .opacity(selected ? 1 : 0)
                .contentTransition(.numericText())
        }
        .frame(width: 26, height: 26)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.5), value: shown)
    }

    private func add() {
        reasons.add(draft)
        draft = ""
    }

    private func delete(_ reason: ReasonsStore.Custom) {
        withAnimation(.snappy(duration: 0.25)) { reasons.remove(reason) }
    }
}
