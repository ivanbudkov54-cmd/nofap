//
//  ChatThreadView.swift
//  NoFap
//
//  Переписка — общая для напарника и сквада. Главное здесь — не текст,
//  а кнопка сигнала: в момент тяги нужно уметь позвать на помощь одним
//  движением, ничего не набирая.
//

import SwiftUI

struct PartnerChatView: View {

    @Environment(PartnerManager.self) private var partner

    var body: some View {
        ChatThreadView(
            title: partner.partner?.nickname ?? String(localized: "Напарник"),
            messages: partner.messages,
            isSending: partner.isSending,
            showsSenders: false,
            emptyNote: "Напиши первым или нажми кнопку внизу, когда станет тяжело.",
            start: {
                await partner.loadMessages()
                partner.startWatchingChat()
            },
            stop: { partner.stopWatchingChat() },
            send: { text, kind in await partner.send(text, kind: kind) }
        )
    }
}

struct SquadChatView: View {

    @Environment(SquadManager.self) private var squad

    var body: some View {
        ChatThreadView(
            title: String(localized: "Сквад"),
            messages: squad.messages,
            isSending: squad.isSending,
            showsSenders: true,
            emptyNote: "Это общий чат сквада — его видят все участники. Напиши первым или позови на помощь кнопкой внизу.",
            start: {
                await squad.loadMessages()
                squad.startWatchingChat()
            },
            stop: { squad.stopWatchingChat() },
            send: { text, kind in await squad.send(text, kind: kind) }
        )
    }
}

struct ChatThreadView: View {

    let title: String
    let messages: [PartnerMessage]
    let isSending: Bool
    /// В групповом чате над чужими сообщениями — имя автора.
    let showsSenders: Bool
    let emptyNote: LocalizedStringResource
    let start: () async -> Void
    let stop: () -> Void
    let send: (String, PartnerMessage.Kind) async -> Void

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            feed
            signalBar
            input
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await start() }
        .onDisappear { stop() }
    }

    // MARK: - Лента

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if messages.isEmpty { placeholder }

                    ForEach(messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            // Лента опрашивается раз в две секунды, и безымянный withAnimation
            // (easeInOut ~0.35с) дёргал экран под рукой у читающего. Теперь
            // короткий easeOut — и только если пришло новое.
            .onChange(of: messages.count) { previous, current in
                guard current > previous, let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Text("Здесь пусто")
                .font(Face.display(20, .medium))
                .foregroundStyle(Palette.marbleHigh)

            Text(emptyNote)
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    private func bubble(_ message: PartnerMessage) -> some View {
        HStack {
            if message.isMine { Spacer(minLength: 50) }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if showsSenders, !message.isMine, let name = message.senderName {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                }

                if message.isSignal {
                    Label(message.text, systemImage: "exclamationmark.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.goldFill)
                } else {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundStyle(message.isMine ? Color(hex: 0x1A1405) : Palette.marbleHigh)
                }

                Text(message.sentAt, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(message.isMine && !message.isSignal
                                     ? Color(hex: 0x1A1405).opacity(0.6)
                                     : Palette.ash)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background(for: message))
            .overlay {
                if message.isSignal {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Palette.gold.opacity(0.6), lineWidth: 1)
                }
            }

            if !message.isMine { Spacer(minLength: 50) }
        }
    }

    /// Своё — золотом, чужое — камнем, сигнал тяги — отдельно, чтобы его
    /// нельзя было пролистать глазами как обычную реплику.
    @ViewBuilder
    private func background(for message: PartnerMessage) -> some View {
        if message.isSignal {
            RoundedRectangle(cornerRadius: 16).fill(Palette.gold.opacity(0.14))
        } else if message.isMine {
            RoundedRectangle(cornerRadius: 16).fill(.goldFill)
        } else {
            RoundedRectangle(cornerRadius: 16).fill(Palette.basalt)
        }
    }

    // MARK: - Сигнал и быстрые ответы

    private var signalBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    Task { await send(ChatPresets.sos, .sos) }
                } label: {
                    Label(ChatPresets.sos, systemImage: "hand.raised.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Capsule().fill(.goldFill))
                }

                ForEach(ChatPresets.support, id: \.self) { text in
                    Button {
                        Task { await send(text, .support) }
                    } label: {
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.marble)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .overlay { Capsule().strokeBorder(Palette.vein, lineWidth: 1) }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .disabled(isSending)
    }

    private var input: some View {
        HStack(spacing: 10) {
            TextField("Написать…", text: $draft, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marbleHigh)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.basalt, in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Palette.vein, lineWidth: 1)
                }

            Button {
                let text = draft
                draft = ""
                Task { await send(text, .text) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.goldFill))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
