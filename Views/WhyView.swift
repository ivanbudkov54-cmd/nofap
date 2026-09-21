//
//  WhyView.swift
//  NoFap
//
//  Личные причины — то, к чему возвращаешься в момент тяги, а не статистика.
//  Отдельно от «Прогресса» по смыслу, поэтому не вкладка, а переход с неё.
//

import SwiftUI

private struct Reason: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

private let builtInReasons: [Reason] = [
    Reason(icon: "bolt.fill", title: "Больше энергии", subtitle: "Ты чувствуешь себя живым"),
    Reason(icon: "sparkles", title: "Лучший внешний вид", subtitle: "Тестостерон на максимуме"),
    Reason(icon: "checkmark.shield.fill", title: "Уверенность", subtitle: "Ты уважаешь себя"),
    Reason(icon: "brain.head.profile", title: "Фокус и продуктивность", subtitle: "Меньше тумана в голове"),
    Reason(icon: "heart.fill", title: "Настоящие отношения", subtitle: "Ты готов к настоящей любви"),
    Reason(icon: "lock.open.fill", title: "Свобода от зависимости", subtitle: "Ты хозяин своих желаний"),
]

struct WhyView: View {

    @State private var customReasons: [String] = UserDefaults.standard.stringArray(forKey: "customReasons") ?? []
    @State private var selected: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "selectedReasons") ?? [])
    @State private var isAdding = false
    @State private var draft = ""

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
                        row(icon: reason.icon, title: reason.title, subtitle: reason.subtitle, key: reason.title)
                        if index < builtInReasons.count - 1 || !customReasons.isEmpty {
                            Divider().overlay(Palette.vein).padding(.leading, 62)
                        }
                    }

                    ForEach(Array(customReasons.enumerated()), id: \.offset) { index, text in
                        row(icon: "star.fill", title: text, subtitle: "Твоя причина", key: text)
                            .swipeActions {
                                Button("Удалить", role: .destructive) { remove(at: index) }
                            }
                        if index < customReasons.count - 1 {
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

    private func row(icon: String, title: String, subtitle: String, key: String) -> some View {
        Button {
            toggle(key)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.goldFill)
                    .frame(width: 34, height: 34)
                    .background(Palette.gold.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Face.display(16, .medium))
                        .foregroundStyle(Palette.marbleHigh)
                    Text(subtitle)
                        .font(Face.display(13))
                        .foregroundStyle(Palette.ash)
                }

                Spacer()

                // Отметка «это моя причина» — не статистика, а личный якорь.
                ZStack {
                    Circle()
                        .strokeBorder(selected.contains(key) ? Palette.gold : Palette.vein, lineWidth: 1.6)
                        .background(Circle().fill(selected.contains(key) ? Palette.gold.opacity(0.16) : .clear))
                        .frame(width: 26, height: 26)

                    if selected.contains(key) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.goldFill)
                    }
                }
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ key: String) {
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
        UserDefaults.standard.set(Array(selected), forKey: "selectedReasons")
    }

    private func add() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        guard !trimmed.isEmpty else { return }
        customReasons.append(trimmed)
        UserDefaults.standard.set(customReasons, forKey: "customReasons")
    }

    private func remove(at index: Int) {
        customReasons.remove(at: index)
        UserDefaults.standard.set(customReasons, forKey: "customReasons")
    }
}
