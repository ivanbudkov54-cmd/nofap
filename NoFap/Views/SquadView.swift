//
//  SquadView.swift
//  NoFap
//

import SwiftUI
import UIKit

struct SquadView: View {
    @Environment(SquadManager.self) private var squads
    @State private var squadName = ""
    @State private var joinCode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let squad = squads.squad {
                    roster(squad)
                } else {
                    empty
                }
                if let error = squads.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.marbleHigh)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationTitle("Мой сквад")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await squads.refresh() }
    }

    private func roster(_ squad: SquadModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(squad.name)
                .font(Face.display(24, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Button {
                UIPasteboard.general.string = squad.squadCode
            } label: {
                Text("🔥 Общий стрик сквада: \(squad.totalStreakDays) дней")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.gold)
            Text("Код: \(squad.squadCode)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            ForEach(Array(squad.members.sorted { $0.streakDays > $1.streakDays }.enumerated()), id: \.element.id) { index, member in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(index + 1). \(member.name)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        Text("В строю: \(member.streakDays) дн.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ash)
                    }
                    Spacer()
                }
                .padding(14)
                .cardSurface()
            }
            Button("Выйти из сквада") {
                Task { await squads.leaveSquad() }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.red)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сквада пока нет")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            TextField("Название сквада", text: $squadName)
                .textFieldStyle(.roundedBorder)
            Button("Создать сквад") {
                Task { await squads.createSquad(name: squadName) }
            }
            .buttonStyle(GoldButton())
            .disabled(squadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            TextField("Код приглашения", text: $joinCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
            Button("Вступить по коду") {
                Task { await squads.joinSquad(code: joinCode) }
            }
            .buttonStyle(GoldButton())
            .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct BuddyCard: View {
    @Environment(BuddyManager.self) private var buddies
    @Environment(SquadManager.self) private var squads
    @State private var showInvite = false
    @State private var showChat = false
    @State private var showShare = false
    @State private var shareError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Братство и сквад")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)

            if let buddy = buddies.currentBuddy {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Palette.gold)
                            .frame(width: 40, height: 40)
                            .background(Palette.gold.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(buddy.username)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.marbleHigh)
                            Text("В строю: \(buddy.streakDays) дн.")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.marble)
                            Text(buddy.checkinNote)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.ash)
                        }
                        Spacer()
                    }
                    Button("Чат") { showChat = true }
                        .buttonStyle(GoldButton())
                    shareButton
                }
                .padding(14)
                .cardSurface()
            } else {
                Button { showInvite = true } label: {
                    HStack {
                        Text("Найти напарника по коду")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Palette.ash)
                    }
                    .padding(14)
                    .cardSurface()
                }
                .buttonStyle(.plain)
                shareButton
            }

            if let squad = squads.squad {
                NavigationLink {
                    SquadView()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(squad.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        Text("🔥 Общий стрик сквада: \(squad.totalStreakDays) дней")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.gold)
                        HStack(spacing: -8) {
                            ForEach(squad.members.sorted { $0.streakDays > $1.streakDays }.prefix(3), id: \.id) { member in
                                Text(String(member.name.prefix(1)))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: 0x1A1405))
                                    .frame(width: 28, height: 28)
                                    .background(Palette.gold, in: Circle())
                                    .overlay { Circle().strokeBorder(Palette.obsidian, lineWidth: 2) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .cardSurface()
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    SquadView()
                } label: {
                    HStack {
                        Text("Создать сквад или войти по коду")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Palette.ash)
                    }
                    .padding(14)
                    .cardSurface()
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            buddies.startWatching()
            await squads.fetchSquadDetails()
        }
        .onDisappear { buddies.stopWatching() }
        .sheet(isPresented: $showInvite) { PairBuddySheet() }
        .sheet(isPresented: $showShare) {
            if let code = buddies.inviteCode {
                BuddyInviteSheet(code: code)
            }
        }
        .alert("Код приглашения", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        } message: {
            Text(shareError ?? "")
        }
        .sheet(isPresented: $showChat) { BuddyChatView() }
    }

    private var shareButton: some View {
        Button {
            Task {
                if buddies.inviteCode == nil { await buddies.refresh() }
                if buddies.inviteCode != nil {
                    showShare = true
                } else {
                    shareError = buddies.errorMessage ?? "Не удалось получить код. Проверь интернет и попробуй ещё раз."
                }
            }
        } label: {
            Label("Поделиться", systemImage: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x1A1405))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct BuddyInviteSheet: View {
    let code: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Приглашение напарника")
                    .font(Face.display(24, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                Text("Друг вводит этот код у себя или открывает ссылку.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)
                Text(InviteLinkHelper.grouped(code))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity)
                Text(InviteLinkHelper.shareText(for: code))
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.marble)
                ShareLink(
                    item: InviteLinkHelper.generateInviteURL(for: code),
                    message: Text(InviteLinkHelper.shareText(for: code))
                ) {
                    Label("Отправить", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Spacer()
            }
            .padding(20)
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct PairBuddyConfirmationSheet: View {
    @Environment(BuddyManager.self) private var buddies
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text(buddies.foundBuddy.map { "Вы хотите объединиться с \($0.username)?" }
                     ?? "Вы хотите связать стрик с пользователем по коду \(buddies.pendingBuddyCode ?? "")?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.center)
                if buddies.isLoading { ProgressView() }
                if let error = buddies.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ash)
                        .multilineTextAlignment(.center)
                }
                Button("Подтвердить") {
                    Task {
                        await buddies.confirmPair()
                        if buddies.currentBuddy != nil { dismiss() }
                    }
                }
                .onAppear {
                    if let code = buddies.pendingBuddyCode {
                        Task { await buddies.searchBuddy(inputCode: code) }
                    }
                }
                .buttonStyle(GoldButton())
                .disabled(buddies.isLoading)
                Button("Отмена") {
                    buddies.pendingBuddyCode = nil
                    dismiss()
                }
                .foregroundStyle(Palette.ash)
                Spacer()
            }
            .padding(24)
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationTitle("Напарник")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

struct PairBuddySheet: View {
    @Environment(BuddyManager.self) private var buddies
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Код из 6 знаков", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .onChange(of: code) { _, raw in
                        buddies.noteCodeChanged(raw)
                    }
                if let found = buddies.foundBuddy {
                    Text("Вы хотите объединиться с \(found.username)?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                    Button("Подтвердить") {
                        Task {
                            await buddies.confirmPair()
                            if buddies.currentBuddy != nil { dismiss() }
                        }
                    }
                    .buttonStyle(GoldButton())
                    .disabled(buddies.isLoading)
                } else {
                    Button("Синхронизироваться") {
                        Task { await buddies.searchBuddy(inputCode: code) }
                    }
                    .buttonStyle(GoldButton())
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 || buddies.isLoading)
                }
                if buddies.isLoading { ProgressView() }
                if let error = buddies.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ash)
                }
                Spacer()
            }
            .padding(20)
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationTitle("Напарник")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

struct BuddyChatView: View {
    @Environment(BuddyManager.self) private var buddies
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    private let presets = ["Держись, брат! 💪", "Сделай 20 отжиманий прямо сейчас", "Не ведись на импульс"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let buddy = buddies.currentBuddy {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(buddy.username)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        Text("\(buddy.checkinNote) · \(buddy.streakDays) дн.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ash)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(buddies.chatMessages) { message in
                            let mine = message.senderId != buddies.currentBuddy?.id
                            HStack {
                                if mine { Spacer(minLength: 40) }
                                Text(message.text)
                                    .font(.system(size: 15))
                                    .foregroundStyle(mine ? Color(hex: 0x1A1405) : Palette.marbleHigh)
                                    .padding(12)
                                    .background(mine ? Palette.gold : Palette.basalt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                if !mine { Spacer(minLength: 40) }
                            }
                        }
                    }
                    .padding(16)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.self) { preset in
                            Button(preset) { Task { await buddies.sendMessage(text: preset) } }
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Palette.vein, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                }
                HStack {
                    TextField("Сообщение", text: $draft)
                        .textFieldStyle(.roundedBorder)
                    Button("Отправить") {
                        let text = draft
                        draft = ""
                        Task { await buddies.sendMessage(text: text) }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
            }
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationTitle("Чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task { buddies.subscribeToRealtimeChat() }
            .onDisappear { buddies.stopRealtimeChat() }
        }
    }
}
