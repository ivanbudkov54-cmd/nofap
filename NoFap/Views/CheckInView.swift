//
//  CheckInView.swift
//  NoFap
//
//  Экспресс-чекин: пара ползунков и теги — быстрее полноценной записи в
//  дневник. Экран нарочно тёмный и «мужской», в отличие от светлой темы
//  остального приложения — короткая пауза для честной самооценки, а не
//  ещё одна светлая карточка среди прочих.
//

import SwiftUI

/// Локальная тёмная палитра только для этого экрана. Не трогает Palette
/// из Theme.swift — остальное приложение светлое, и не должно меняться.
private enum Ink {
    static let background = Color(hex: 0x0A0A0D)
    static let card        = Color(hex: 0x17171C)
    static let border      = Color(hex: 0x2B2B33)
    static let textPrimary = Color(hex: 0xF2F2F5)
    static let textSecondary = Color(hex: 0x8C8C97)
    static let accent      = Palette.gold
    static let urge        = Color(hex: 0xE05A45)
}

struct CheckInView: View {

    @Environment(CheckInManager.self) private var checkIns
    @Environment(JournalManager.self) private var journal
    @Environment(Backend.self) private var backend
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var energy: Double = 5
    @State private var libido: Double = 5
    @State private var selectedTags: Set<CheckInTag> = []
    @State private var note = ""
    @State private var isSaving = false
    @State private var showSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                energySlider
                libidoSlider
                triggerPicker
                noteField
                saveButton
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Ink.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Ink.textSecondary)
                }
            }
        }
        .toolbarBackground(Ink.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Запись сохранена", isPresented: $showSaved) {
            Button("Ок") { dismiss() }
        } message: {
            Text("Экспресс-чекин добавлен в дневник.")
        }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Экспресс-чекин")
                .font(Face.display(26, .semibold))
                .foregroundStyle(Ink.textPrimary)

            Text("30 секунд, чтобы честно зафиксировать день.")
                .font(.system(size: 14))
                .foregroundStyle(Ink.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Ползунки

    private var energySlider: some View {
        lockedSlider(
            sliderCard(
                title: "Уровень энергии",
                value: energy,
                tint: Ink.accent
            ) {
                Slider(value: $energy, in: 1...10, step: 1)
                    .tint(Ink.accent)
                    .disabled(!subscriptions.isPro)
            }
        )
    }

    private var libidoSlider: some View {
        lockedSlider(
            sliderCard(
                title: "Уровень либидо / тяги",
                value: libido,
                tint: Ink.urge
            ) {
                Slider(value: $libido, in: 1...10, step: 1)
                    .tint(Ink.urge)
                    .disabled(!subscriptions.isPro)
            }
        )
    }

    private func lockedSlider<Content: View>(_ content: Content) -> some View {
        content
            .overlay {
                if !subscriptions.isPro {
                    Button {
                        subscriptions.checkProAccess(for: "Отслеживание уровня энергии и физического тонуса входит в Pro") {}
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                            VStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(Palette.gold)
                                Text("Доступно в Pro")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Ink.textPrimary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
    }

    private func sliderCard(
        title: String,
        value: Double,
        tint: Color,
        @ViewBuilder slider: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.string(title).localizedUppercase)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Ink.textSecondary)

                Spacer()

                Text("\(Int(value))")
                    .font(Face.display(15, .semibold))
                    .foregroundStyle(Color(hex: 0x0A0A0D))
                    .frame(width: 30, height: 30)
                    .background(tint, in: .circle)
            }

            slider()
        }
        .padding(16)
        .background(Ink.card, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.border, lineWidth: 1)
        }
    }

    // MARK: - Триггеры

    private var triggerPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ТРИГГЕРЫ ЗА ДЕНЬ")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(CheckInTag.allCases) { tag in
                    tagChip(tag)
                }
            }
        }
    }

    private func tagChip(_ tag: CheckInTag) -> some View {
        let isSelected = selectedTags.contains(tag)

        return Button {
            toggle(tag)
        } label: {
            Text(tag.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color(hex: 0x0A0A0D) : Ink.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? Ink.accent : Ink.card, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(isSelected ? .clear : Ink.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    /// "None" исключает остальные теги и наоборот — нельзя одновременно
    /// сказать "триггеров не было" и перечислить их.
    private func toggle(_ tag: CheckInTag) {
        if tag == .none {
            selectedTags = selectedTags.contains(.none) ? [] : [.none]
        } else if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.remove(.none)
            selectedTags.insert(tag)
        }
    }

    // MARK: - Заметка

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("МЫСЛИ ДНЯ / ЗАМЕТКА")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.textSecondary)

            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Опиши победы или триггеры дня...")
                        .font(.system(size: 15))
                        .foregroundStyle(Ink.textSecondary.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $note)
                    .font(.system(size: 15))
                    .foregroundStyle(Ink.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(height: 120)
            }
            .background(Ink.card, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.border, lineWidth: 1)
            }
        }
    }

    // MARK: - Сохранение

    private var saveButton: some View {
        Button {
            save()
        } label: {
            ZStack {
                if isSaving {
                    ProgressView()
                        .tint(Color(hex: 0x1A1405))
                } else {
                    Text("Сохранить запись")
                }
            }
            .font(.system(size: 17, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color(hex: 0x1A1405))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(.goldFill))
        }
        .disabled(isSaving)
        .opacity(isSaving ? 0.85 : 1)
        .padding(.top, 4)
    }

    private func save() {
        // Фиксируем дату и точный ISO-таймштамп в момент нажатия — не
        // после закрытия лоадера, чтобы отметка совпадала с реальным
        // моментом чекина, а не с его отображением.
        let date = Date()
        let energyValue = subscriptions.isPro ? Int(energy) : nil
        let libidoValue = subscriptions.isPro ? Int(libido) : nil
        let tags = Array(selectedTags)
        let noteText = note

        Task {
            isSaving = true
            journal.addEntry(noteText, moodScore: energyValue, urgeScore: libidoValue, on: date)
            if let energyValue, let libidoValue {
                checkIns.addEntry(
                    energyLevel: energyValue,
                    libidoLevel: libidoValue,
                    triggers: tags,
                    note: noteText,
                    on: date
                )
            }
            await backend.saveJournal(
                mood: energyValue,
                urge: libidoValue,
                prompt: nil,
                note: noteText,
                into: journal
            )
            isSaving = false
            if backend.notice == nil {
                showSaved = true
            }
        }
    }
}

/// Простая обёртка тегов с переносом строк — HStack сам не умеет,
/// а полноценный Layout не нужен для семи коротких слов.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
