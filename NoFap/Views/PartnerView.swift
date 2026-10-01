//
//  PartnerView.swift
//  NoFap
//
//  Экран напарника: один человек, не лента. Двое идут параллельно и видят
//  счёт друг друга — то, что удерживает лучше одинокого счётчика.
//

import SwiftUI

struct PartnerView: View {

    @Environment(PartnerManager.self) private var partner

    @State private var enteringCode = false
    @State private var codeDraft = ""
    @State private var nicknameDraft = ""
    @State private var showUnpairConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                switch partner.state {
                case .unknown:      loading
                case .solo:         solo
                case .inviting(let invite): inviting(invite)
                case .paired(let profile):  paired(profile)
                case .failed(let message):  failure(message)
                }

                SquadSection()
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .task {
            nicknameDraft = partner.nickname
            if case .unknown = partner.state { await partner.refresh() }
        }
        .sheet(isPresented: $enteringCode) { codeSheet }
        .confirmationDialog("Разорвать связь?",
                            isPresented: $showUnpairConfirm,
                            titleVisibility: .visible) {
            Button("Разорвать", role: .destructive) {
                Task { await partner.unpair() }
            }
        } message: {
            Text("Вы перестанете видеть счёт друг друга. Твой прогресс останется при тебе.")
        }
    }

    // MARK: - Состояния

    private var loading: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Palette.gold)
            Text("Проверяем связь…")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
        }
        .padding(.top, 80)
    }

    private var solo: some View {
        VStack(spacing: 20) {
            header(title: "Одному тяжелее",
                   note: "Когда кто-то видит твой счёт, сорваться труднее. Позови одного человека, которому доверяешь.")

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "что увидит напарник")
                bullet("сколько дней ты держишься", symbol: "eye")
                bullet("отметился ли ты сегодня", symbol: "eye")

                Eyebrow(text: "чего не увидит")
                    .padding(.top, 8)
                bullet("календарь и даты", symbol: "eye.slash")
                bullet("историю срывов", symbol: "eye.slash")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardSurface()

            nicknameField

            VStack(spacing: 12) {
                Button("Создать код") {
                    partner.setNickname(nicknameDraft)
                    Task { await partner.createInvite() }
                }
                .buttonStyle(GoldButton())

                Button("У меня есть код") {
                    partner.setNickname(nicknameDraft)
                    codeDraft = ""
                    enteringCode = true
                }
                .buttonStyle(EngravedButton())
            }
        }
    }

    private func inviting(_ invite: PartnerInvite) -> some View {
        VStack(spacing: 20) {
            header(title: "Позови напарника",
                   note: "Отправь приглашение — друг откроет ссылку и подтвердит. Или продиктуй код: он одноразовый и скоро истечёт.")

            Text(invite.grouped)
                .font(Face.display(44, .semibold))
                .tracking(4)
                .foregroundStyle(.goldFill)
                .shadow(color: Palette.goldLight.opacity(0.7), radius: 10)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .cardSurface()

            // Системный таймер вместо своего `Timer.publish`: тот тикал раз в
            // секунду и перерисовывал весь экран во всех состояниях, включая
            // те, где никакого отсчёта нет.
            HStack(spacing: 4) {
                Text("Истекает через")
                Text(invite.expiresAt, style: .timer)
            }
            .font(.system(size: 14))
            .foregroundStyle(Palette.ash)

            HStack(spacing: 10) {
                ProgressView().tint(Palette.gold)
                Text("Ждём напарника…")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.marble)
            }

            ShareLink(item: inviteMessage(invite)) {
                Text("Отправить приглашение")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(.goldFill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1) }
            }

            Button("Отменить") { Task { await partner.cancelInvite() } }
                .buttonStyle(StoneButton())
        }
    }

    private func paired(_ profile: PartnerProfile) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                Eyebrow(text: "твой напарник")

                Text(profile.nickname)
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                PartnerBadge(width: 150, showsCount: false)

                Text("\(profile.currentStreak)")
                    .font(Face.display(52, .semibold))
                    .foregroundStyle(.goldFill)
                    .contentTransition(.numericText())

                Text("из \(profile.goalDays) дней")
                    .font(Face.display(14))
                    .foregroundStyle(Palette.ash)

                statusLine(for: profile)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .cardSurface()

            if profile.isStale {
                Text("Данные не обновлялись больше суток — напарник давно не заходил.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink {
                PartnerChatView()
            } label: {
                Label("Написать", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(.goldFill))
                    .shadow(color: Palette.gold.opacity(0.28), radius: 14, y: 4)
            }

            Button("Разорвать связь") { showUnpairConfirm = true }
                .buttonStyle(StoneButton())
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Palette.gold)

            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(Palette.marble)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Повторить") { Task { await partner.refresh() } }
                .buttonStyle(EngravedButton())
        }
        .padding(.top, 60)
    }

    // MARK: - Части

    private func header(title: LocalizedStringResource, note: LocalizedStringResource) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Face.display(26, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(note)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Маркер — SF Symbol, а не набранное тире: символ ещё и несёт смысл
    /// пункта («увидит» / «не увидит»), а не просто отбивает строку.
    private func bullet(_ text: LocalizedStringResource, symbol: String) -> some View {
        Label {
            Text(text)
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Palette.gold)
                .imageScale(.small)
        }
        .font(.system(size: 14))
    }

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "как тебя звать напарнику")

            TextField("Прозвище", text: $nicknameDraft)
                .font(Face.display(17, .medium))
                .foregroundStyle(Palette.marbleHigh)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Palette.basalt, in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Palette.vein, lineWidth: 1)
                }

            Text("Имя увидит только напарник.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.ash)
        }
    }

    /// При стрике 0 «держится» звучало бы неуместно — человек отметился,
    /// но счёт обнулился. Формулировка нейтральная.
    private func statusLine(for profile: PartnerProfile) -> some View {
        let holding = profile.isHoldingToday
        let text: LocalizedStringResource = holding
            ? (profile.currentStreak == 0 ? "отметился сегодня" : "держится сегодня")
            : "сегодня ещё не отмечался"

        return Label {
            Text(text)
                .foregroundStyle(holding ? Palette.marble : Palette.ash)
        } icon: {
            Image(systemName: holding ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(holding ? Palette.gold : Palette.vein)
                .imageScale(.small)
        }
        .font(.system(size: 14))
    }

    /// Текст нейтральный: сообщение может увидеть кто угодно через плечо
    /// или в превью уведомления. Код продублирован для того, у кого
    /// ссылка не открылась или кто диктует его голосом.
    private func inviteMessage(_ invite: PartnerInvite) -> String {
        let link = PartnerLink.url(for: invite.code, from: partner.nickname).absoluteString
        return String(localized: "Давай держаться вместе — стань моим напарником.\n\nОткрой ссылку: \(link)\nИли введи код \(invite.grouped) в разделе «Напарник».")
    }

    private var codeSheet: some View {
        VStack(spacing: 22) {
            Text("Введи код друга")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .padding(.top, 28)

            PartnerCodeEntry(code: $codeDraft) { code in
                enteringCode = false
                Task { await partner.redeem(code: code) }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(260)])
        .presentationBackground(Palette.obsidian)
    }

}
