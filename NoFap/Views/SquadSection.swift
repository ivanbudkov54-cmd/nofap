//
//  SquadSection.swift
//  NoFap
//
//  Раздел «Сквад» на экране напарника — отдельной карточкой со своим
//  заголовком, чтобы группа и напарник один на один не смешивались.
//

import SwiftUI

struct SquadSection: View {

    @Environment(SquadManager.self) private var squad
    @Environment(PartnerManager.self) private var partner
    @Environment(StreakManager.self) private var streak

    @State private var enteringCode = false
    @State private var codeDraft = ""
    @State private var showLeaveConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            switch squad.state {
            case .unknown:
                ProgressView().tint(Palette.gold).frame(maxWidth: .infinity)
            case .none:
                empty
            case .active(let snapshot):
                active(snapshot)
            case .failed(let message):
                failure(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
        .onAppear { squad.startWatchingMembers() }
        .onDisappear { squad.stopWatchingMembers() }
        .sheet(isPresented: $enteringCode) { codeSheet }
        .alert("Выйти из сквада?", isPresented: $showLeaveConfirm) {
            Button("Выйти", role: .destructive) { Task { await squad.leave() } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Ты перестанешь видеть участников и общий чат. Вернуться можно только по новому приглашению.")
        }
    }

    // MARK: - Состояния

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "сквад", color: Palette.gold)
            Text("Держитесь группой")
                .font(Face.display(20, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Text("До четырёх человек: видите дни друг друга и пишете в общий чат. Напарник — отдельно, один на один.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Button("Собрать сквад") { Task { await squad.createInvite() } }
                .buttonStyle(GoldButton())
                .disabled(squad.isBusy)

            Button("У меня есть код") {
                codeDraft = ""
                enteringCode = true
            }
            .buttonStyle(EngravedButton())
        }
    }

    private func active(_ snapshot: SquadSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                memberRow(name: String(localized: "Ты"),
                          streak: streak.currentStreak,
                          holding: streak.hasCheckedInToday,
                          stale: false)
                ForEach(snapshot.members) { member in
                    memberRow(name: member.nickname,
                              streak: member.currentStreak,
                              holding: member.isHoldingToday,
                              stale: member.isStale)
                }
                ForEach(0..<squad.freeSlots, id: \.self) { _ in
                    emptySlotRow
                }
            }

            if let invite = snapshot.invite {
                inviteBlock(invite)
            } else if squad.freeSlots > 0 {
                Button("Пригласить в сквад") { Task { await squad.createInvite() } }
                    .buttonStyle(EngravedButton())
                    .disabled(squad.isBusy)
            }

            NavigationLink {
                SquadChatView()
            } label: {
                Label("Чат сквада", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(.goldFill))
            }

            Button("Выйти из сквада") { showLeaveConfirm = true }
                .buttonStyle(StoneButton())
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
            Button("Повторить") { Task { await squad.refresh() } }
                .buttonStyle(StoneButton())
        }
    }

    // MARK: - Участники

    private func memberRow(name: String, streak: Int, holding: Bool, stale: Bool) -> some View {
        HStack(spacing: 12) {
            SquadAvatar(name: name, holding: holding, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.marbleHigh)
                Text(stale ? "давно не заходил"
                           : (holding ? "держится сегодня" : "сегодня ещё не отмечался"))
                    .font(.system(size: 12))
                    .foregroundStyle(holding && !stale ? Palette.marble : Palette.ash)
            }

            Spacer()

            Text("\(streak)")
                .font(Face.display(20, .semibold))
                .foregroundStyle(stale ? AnyShapeStyle(Palette.ash) : AnyShapeStyle(.goldFill))
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var emptySlotRow: some View {
        HStack(spacing: 12) {
            Circle()
                .strokeBorder(Palette.ash.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.ash)
                }
            Text("Свободное место")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
            Spacer()
        }
    }

    // MARK: - Приглашение

    private func inviteBlock(_ invite: PartnerInvite) -> some View {
        VStack(spacing: 12) {
            Text(invite.grouped)
                .font(Face.display(30, .semibold))
                .tracking(4)
                .foregroundStyle(.goldFill)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.obsidian.opacity(0.4), in: .rect(cornerRadius: 14))

            HStack(spacing: 4) {
                Text("Одна ссылка для всех · действует до")
                Text(invite.expiresAt, style: .time)
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.ash)

            ShareLink(item: inviteMessage(invite)) {
                Text("Отправить приглашение")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.goldFill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1) }
            }

            Button("Отменить приглашение") { Task { await squad.cancelInvite() } }
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
        }
    }

    /// Нейтральный текст — как у напарника: его могут увидеть в превью
    /// уведомления. Код продублирован для тех, у кого ссылка не открылась.
    private func inviteMessage(_ invite: PartnerInvite) -> String {
        let link = PartnerLink.url(for: invite.code, kind: .squad, from: partner.nickname).absoluteString
        return String(localized: "Зову тебя в наш сквад — держимся вместе.\n\nОткрой ссылку: \(link)\nИли введи код \(invite.grouped) в разделе «Напарник» → «Сквад».")
    }

    // MARK: - Ввод кода

    private var codeSheet: some View {
        VStack(spacing: 22) {
            Text("Код сквада")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .padding(.top, 28)

            PartnerCodeEntry(code: $codeDraft) { code in
                enteringCode = false
                Task { await squad.join(code: code) }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(260)])
        .presentationBackground(Palette.obsidian)
    }
}

/// Круглая аватарка участника: первая буква прозвища. Золотое кольцо —
/// отметился сегодня, тусклое — ещё нет.
struct SquadAvatar: View {
    let name: String
    let holding: Bool
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Palette.basalt)
            .overlay {
                Circle().strokeBorder(holding ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.vein),
                                      lineWidth: size * 0.05)
            }
            .overlay {
                Text(name.prefix(1).uppercased())
                    .font(Face.display(size * 0.4, .semibold))
                    .foregroundStyle(holding ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.marble))
            }
            .frame(width: size, height: size)
    }
}
