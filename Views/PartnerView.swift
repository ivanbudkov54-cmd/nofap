//
//  PartnerView.swift
//  NoFap
//
//  Экран напарника: один человек, не лента. Двое идут параллельно и видят
//  счёт друг друга — то, что удерживает лучше одинокого счётчика.
//

import SwiftUI
import Combine

struct PartnerView: View {

    @Environment(PartnerManager.self) private var partner

    @State private var enteringCode = false
    @State private var codeDraft = ""
    @State private var nicknameDraft = ""
    @State private var showUnpairConfirm = false
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        // now нужен только для обратного отсчёта инвайта — не перерисовываем
        // весь экран каждую секунду в состояниях solo/paired/failed.
        .onReceive(tick) { date in
            if case .inviting = partner.state { now = date }
        }
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
                bullet("сколько дней ты держишься")
                bullet("отметился ли ты сегодня")

                Eyebrow(text: "чего не увидит")
                    .padding(.top, 8)
                bullet("календарь и даты")
                bullet("историю срывов")
                bullet("твоё настоящее имя")
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
            header(title: "Продиктуй этот код",
                   note: "Друг вводит его у себя. Код одноразовый и скоро истечёт.")

            Text(invite.grouped)
                .font(Face.display(44, .semibold))
                .tracking(4)
                .foregroundStyle(.goldFill)
                .shadow(color: Palette.goldLight.opacity(0.7), radius: 10)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .cardSurface()

            Text(remaining(until: invite.expiresAt))
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)

            HStack(spacing: 10) {
                ProgressView().tint(Palette.gold)
                Text("Ждём напарника…")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.marble)
            }

            ShareLink(item: "Мой код в приложении: \(invite.code)") {
                Text("Отправить код")
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

                PartnerBadge(diameter: 120, showsCount: false)

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

    private func header(title: String, note: String) -> some View {
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

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("—").foregroundStyle(Palette.gold)
            Text(text)
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
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

            Text("Имя увидит только напарник. Настоящее лучше не писать.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.ash)
        }
    }

    /// При стрике 0 «держится» звучало бы неуместно — человек отметился,
    /// но счёт обнулился. Формулировка нейтральная.
    private func statusLine(for profile: PartnerProfile) -> some View {
        let holding = profile.isHoldingToday
        let text = holding
            ? (profile.currentStreak == 0 ? "отметился сегодня" : "держится сегодня")
            : "сегодня ещё не отмечался"

        return HStack(spacing: 8) {
            Circle()
                .fill(holding ? Palette.gold : Palette.vein)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(holding ? Palette.marble : Palette.ash)
        }
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

    private func remaining(until date: Date) -> String {
        let left = Int(max(0, date.timeIntervalSince(now)))
        return "Истекает через \(left / 60):" + String(format: "%02d", left % 60)
    }
}
