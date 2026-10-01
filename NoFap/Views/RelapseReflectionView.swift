//
//  RelapseReflectionView.swift
//  NoFap
//
//  Короткий разбор после щита стрика. Без сохранённой записи щит не считается
//  использованным.
//

import SwiftUI

struct RelapseReflectionView: View {

    @Environment(JournalManager.self) private var journal
    @Environment(StreakManager.self) private var streak
    @Environment(Backend.self) private var backend
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var trigger: ShieldTrigger?
    @State private var whenWhere = ""
    @State private var nextTime = ""
    @State private var confirmClose = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Разбор срыва")
                        .font(Face.display(26, .semibold))
                        .foregroundStyle(Palette.marbleHigh)

                    Text("Стрик на месте. Честно разбери, что случилось, и путь продолжится.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ash)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Что послужило главным триггером?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.marbleHigh)

                    FlowChips {
                        ForEach(ShieldTrigger.allCases) { item in
                            Button(item.rawValue) { trigger = item }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(trigger == item ? Color(hex: 0x1A1405) : Palette.marbleHigh)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    if trigger == item {
                                        Capsule().fill(.goldFill)
                                    } else {
                                        Capsule().strokeBorder(Palette.vein, lineWidth: 1)
                                    }
                                }
                        }
                    }

                    field("В какое время и где это произошло?", text: $whenWhere)
                    field("Что можно сделать в следующий раз при подобном импульсе?", text: $nextTime)

                    Button("Сохранить разбор и продолжить путь") {
                        save()
                    }
                    .buttonStyle(GoldButton())
                    .disabled(trigger == nil)
                    .opacity(trigger == nil ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmClose = true
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Palette.ash)
                    }
                }
            }
            .interactiveDismissDisabled()
            .alert("Чтобы сохранить стрик, заверши запись разбора", isPresented: $confirmClose) {
                Button("Продолжить разбор", role: .cancel) {}
                Button("Закрыть без сохранения", role: .destructive) {
                    streak.restoreStreakFreeze(router.freezeDateBeforeShield)
                    saved = true
                    dismiss()
                }
            }
        }
        .onDisappear {
            if !saved {
                streak.restoreStreakFreeze(router.freezeDateBeforeShield)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.marbleHigh)
            TextField("Напиши здесь", text: text, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Palette.basalt, in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.vein, lineWidth: 1)
                }
        }
    }

    private func save() {
        guard let trigger else { return }
        var lines = ["Триггер: \(trigger.rawValue)"]
        let place = whenWhere.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = nextTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if !place.isEmpty { lines.append("Где и когда: \(place)") }
        if !plan.isEmpty { lines.append("В следующий раз: \(plan)") }
        let text = lines.joined(separator: "\n")
        journal.addEntry(text, promptQuestion: JournalEntry.shieldBadge, isShieldReview: true)
        saved = true
        router.toast = "Стрик сохранен. Сделай выводы и двигайся дальше!"
        Task {
            await backend.saveJournal(mood: nil, urge: nil, prompt: JournalEntry.shieldBadge, note: text, into: journal)
        }
        dismiss()
    }
}

enum ShieldTrigger: String, CaseIterable, Identifiable {
    case stress = "Стресс"
    case boredom = "Скука"
    case loneliness = "Одиночество"
    case fatigue = "Усталость"
    case social = "Соцсети"
    case alcohol = "Алкоголь"
    case other = "Другое"

    var id: String { rawValue }
}

private struct FlowChips: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var origins: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), origins)
    }
}
