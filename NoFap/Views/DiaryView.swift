//
//  DiaryView.swift
//  NoFap
//
//  Личный дневник: пара строк о том, как прошёл день, и экспресс-чекины
//  с энергией/тягой/триггерами. Оба типа записей живут в одной ленте,
//  отсортированной по времени — так дневник читается как единая история,
//  а не два несвязанных списка.
//

import SwiftUI

struct DiaryView: View {

    @Environment(JournalManager.self) private var journal
    @Environment(CheckInManager.self) private var checkIns

    @State private var showEditor = false
    @State private var showCheckIn = false
    @State private var draft = ""
    @State private var currentPrompt = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM, HH:mm"
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()

    /// Единая лента: свободные записи и экспресс-чекины вместе, по дате.
    private enum FeedItem: Identifiable {
        case note(JournalEntry)
        case checkIn(CheckInEntry)

        var id: String {
            switch self {
            case .note(let e):    "note-\(e.id)"
            case .checkIn(let e): "checkin-\(e.id)"
            }
        }

        var date: Date {
            switch self {
            case .note(let e):    e.date
            case .checkIn(let e): e.date
            }
        }
    }

    private var feed: [FeedItem] {
        (journal.entries.map(FeedItem.note) + checkIns.entries.map(FeedItem.checkIn))
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                checkInEntry

                if feed.isEmpty {
                    empty
                } else {
                    VStack(spacing: 14) {
                        ForEach(feed) { item in
                            switch item {
                            case .note(let entry):    noteCard(entry)
                            case .checkIn(let entry): checkInCard(entry)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draft = ""
                    currentPrompt = DailyPrompts.next()
                    showEditor = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Palette.gold)
                }
            }
        }
        .sheet(isPresented: $showEditor) { editor }
        .fullScreenCover(isPresented: $showCheckIn) {
            NavigationStack { CheckInView() }
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Дневник")
                .font(Face.display(28, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Text("Пара строк о том, как прошёл день — только для тебя.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    // MARK: - Вход в экспресс-чекин

    private var checkInEntry: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 20))
                    .foregroundStyle(.goldFill)
                    .frame(width: 44, height: 44)
                    .background(Palette.gold.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Экспресс-чекин")
                        .font(Face.display(15, .medium))
                        .foregroundStyle(Palette.marbleHigh)
                    Text("Энергия, тяга, триггеры — 30 секунд")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ash)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ash)
            }
            .padding(14)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Пусто

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Palette.ash)

            Text("Записей пока нет")
                .font(Face.display(16, .medium))
                .foregroundStyle(Palette.marbleHigh)

            Text("Нажми на карандаш вверху или пройди экспресс-чекин выше.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Свободная запись

    private func noteCard(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(Self.dateFormatter.string(from: entry.date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.gold)

                Spacer()

                Button {
                    journal.deleteEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ash)
                }
                .buttonStyle(.plain)
            }

            if let prompt = entry.promptQuestion {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.ash)
                    Text(prompt)
                        .font(.system(size: 12, weight: .medium))
                        .italic()
                        .foregroundStyle(Palette.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(entry.text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface()
    }

    // MARK: - Экспресс-чекин в ленте

    private func checkInCard(_ entry: CheckInEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.gold)
                    Text(Self.dateFormatter.string(from: entry.date))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                }

                Spacer()

                Button {
                    checkIns.deleteEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ash)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 20) {
                levelBadge(title: "Энергия", value: entry.energyLevel)
                levelBadge(title: "Тяга", value: entry.libidoLevel)
            }

            if !entry.triggers.isEmpty {
                TagFlowLayout(spacing: 6) {
                    ForEach(entry.triggers) { tag in
                        Text(tag.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.marble)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Palette.vein.opacity(0.4), in: .capsule)
                    }
                }
            }

            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.marble)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface()
    }

    private func levelBadge(title: String, value: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(value)")
                .font(Face.display(14, .semibold))
                .foregroundStyle(Color(hex: 0x1A1405))
                .frame(width: 26, height: 26)
                .background(.goldFill, in: .circle)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
        }
    }

    // MARK: - Новая запись

    private var editor: some View {
        VStack(spacing: 18) {
            Text("Новая запись")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .padding(.top, 24)

            promptCard

            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Напиши свои мысли здесь...")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.ash.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draft)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.marbleHigh)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(height: 180)
            }
            .background(Palette.basalt, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.vein, lineWidth: 1)
            }

            Button("Сохранить") {
                journal.addEntry(draft, promptQuestion: currentPrompt)
                showEditor = false
            }
            .buttonStyle(GoldButton())
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(560), .large])
        .presentationBackground(Palette.obsidian)
        .presentationDragIndicator(.visible)
    }

    /// Подсказка-вопрос: тёмная карточка на контрасте со светлым экраном
    /// редактора — так она читается как отдельная реплика, а не часть
    /// формы, и явно выделена среди своего окружения.
    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.gold)
                Text("ВОПРОС ДНЯ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: 0x8C8C97))

                Spacer()

                Button {
                    currentPrompt = DailyPrompts.next()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                }
                .buttonStyle(.plain)
            }

            Text(currentPrompt)
                .font(Face.display(15, .medium))
                .foregroundStyle(Color(hex: 0xF2F2F5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(hex: 0x17171C), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.gold.opacity(0.35), lineWidth: 1)
        }
    }
}

/// Простая обёртка тегов с переносом строк — тот же приём, что и в
/// CheckInView, только под светлую тему дневника.
private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 6

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
