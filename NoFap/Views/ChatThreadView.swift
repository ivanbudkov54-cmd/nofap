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
            send: { text, kind in await partner.send(text, kind: kind) },
            chat: .partner,
            // Заблокировать напарника — значит и разорвать пару.
            afterBlock: { await partner.unpair() }
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
            send: { text, kind in await squad.send(text, kind: kind) },
            chat: .squad
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
    let chat: ChatSafety.Chat
    var afterBlock: (() async -> Void)? = nil

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    @State private var safety = ChatSafety.shared
    @State private var reportTarget: PartnerMessage?
    @State private var blockTarget: PartnerMessage?
    @State private var pendingSend: (text: String, kind: PartnerMessage.Kind)?
    @State private var notice: String?

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
        .confirmationDialog("Пожаловаться на сообщение", isPresented: Binding(
            get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }
        ), titleVisibility: .visible, presenting: reportTarget) { message in
            ForEach(ChatSafety.Reason.allCases) { reason in
                Button(reason.title) {
                    Task {
                        let sent = await safety.report(message, reason: reason, in: chat)
                        notice = sent
                            ? String(localized: "Жалоба отправлена. Мы разберём её в течение 24 часов.")
                            : String(localized: "Не получилось отправить жалобу. Проверь интернет и попробуй ещё раз.")
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("Что не так с этим сообщением?")
        }
        .alert(chat == .partner ? "Заблокировать напарника?" : "Заблокировать участника?",
               isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }),
               presenting: blockTarget) { message in
            Button("Заблокировать", role: .destructive) {
                guard let id = message.senderID else { return }
                Task {
                    Haptics.warning()
                    await safety.block(id)
                    await afterBlock?()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text(chat == .partner
                 ? "Пара будет разорвана, его сообщения больше не будут видны."
                 : "Его сообщения больше не будут видны тебе в этом чате.")
        }
        .alert("Правила общения", isPresented: Binding(
            get: { pendingSend != nil }, set: { if !$0 { pendingSend = nil } }
        )) {
            Button("Принимаю") {
                safety.acceptRules()
                if let pending = pendingSend {
                    pendingSend = nil
                    Task { await send(pending.text, pending.kind) }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Здесь поддерживают друг друга. Без оскорблений, угроз, откровенного контента и рекламы. Нарушителей блокируем; на любое сообщение можно пожаловаться, удержав его пальцем.")
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("Хорошо", role: .cancel) {}
        }
    }

    /// Все отправки идут через правила и фильтр.
    private func submit(_ text: String, _ kind: PartnerMessage.Kind) {
        if kind == .text, !safety.isAllowed(text) {
            notice = String(localized: "Сообщение не отправлено: в нём ссылка или грубые слова.")
            return
        }
        guard safety.rulesAccepted else {
            pendingSend = (text, kind)
            return
        }
        Task { await send(text, kind) }
    }

    // MARK: - Лента

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if messages.isEmpty { placeholder }

                    ForEach(messages.filter { !safety.isBlocked($0) }) { message in
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
                        .foregroundStyle(message.isMine ? Palette.onGold : Palette.marbleHigh)
                }

                Text(message.sentAt, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(message.isMine && !message.isSignal
                                     ? Palette.onGold.opacity(0.6)
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
            // Удержать чужое сообщение — пожаловаться или заблокировать автора.
            .contextMenu {
                if !message.isMine {
                    Button(role: .destructive) { reportTarget = message } label: {
                        Label("Пожаловаться", systemImage: "exclamationmark.bubble")
                    }
                    if message.senderID != nil {
                        Button(role: .destructive) { blockTarget = message } label: {
                            Label("Заблокировать", systemImage: "hand.raised.slash")
                        }
                    }
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
            RoundedRectangle(cornerRadius: 16).fill(.goldSurface)
        } else {
            RoundedRectangle(cornerRadius: 16).fill(Palette.basalt)
        }
    }

    // MARK: - Сигнал и быстрые ответы

    private var signalBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    submit(ChatPresets.sos, .sos)
                } label: {
                    Label(ChatPresets.sos, systemImage: "hand.raised.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.onGold)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Capsule().fill(.goldSurface))
                }

                ForEach(ChatPresets.support, id: \.self) { text in
                    Button {
                        submit(text, .support)
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
                guard safety.isAllowed(text) else {
                    notice = String(localized: "Сообщение не отправлено: в нём ссылка или грубые слова.")
                    return
                }
                draft = ""
                submit(text, .text)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.onGold)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.goldSurface))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
