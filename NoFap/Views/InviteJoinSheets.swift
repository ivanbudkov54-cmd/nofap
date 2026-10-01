//
//  InviteJoinSheets.swift
//  NoFap
//
//  Окна «Тебя зовут в напарники / в сквад» по ссылке-приглашению.
//  Всплывают поверх любого экрана, а не на вкладке напарника: переключать
//  вкладку программно нельзя — «Напарник» лежит в меню «Ещё», и привязка
//  выбранной вкладки к состоянию сбрасывала это меню при каждом обновлении
//  данных, выкидывая человека с экрана.
//

import SwiftUI

struct InviteJoinSheets: ViewModifier {

    @Environment(PartnerManager.self) private var partner
    @Environment(SquadManager.self) private var squad

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: partnerPromptShown) { PartnerJoinSheet() }
            .sheet(isPresented: squadPromptShown) { SquadJoinSheet() }
            .alert("У тебя уже есть напарник", isPresented: alreadyPairedShown) {
                Button("Понятно", role: .cancel) {}
            } message: {
                Text("Чтобы связаться с новым, сначала разорви текущую связь.")
            }
    }

    private var partnerPromptShown: Binding<Bool> {
        Binding(
            get: { partner.pendingCode != nil && !partner.isPaired },
            set: { if !$0 { partner.pendingCode = nil } }
        )
    }

    private var alreadyPairedShown: Binding<Bool> {
        Binding(
            get: { partner.pendingCode != nil && partner.isPaired },
            set: { if !$0 { partner.pendingCode = nil } }
        )
    }

    private var squadPromptShown: Binding<Bool> {
        Binding(
            get: { squad.pendingCode != nil },
            set: { if !$0 { squad.pendingCode = nil } }
        )
    }
}

// MARK: - Напарник

private struct PartnerJoinSheet: View {

    @Environment(PartnerManager.self) private var partner
    @State private var nicknameDraft = ""

    var body: some View {
        let code = partner.pendingCode ?? ""
        let title: LocalizedStringResource = partner.pendingInviter.map { "\($0) зовёт тебя в напарники" }
            ?? "Тебя зовут в напарники"

        VStack(spacing: 20) {
            JoinHeader(title: title,
                       note: "Вы будете видеть счёт друг друга. Календарь и срывы останутся только у тебя.")

            JoinCode(code: code)

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
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.vein, lineWidth: 1)
                    }

                Text("Имя увидит только напарник.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.ash)
            }

            VStack(spacing: 12) {
                Button("Связаться") {
                    partner.setNickname(nicknameDraft)
                    partner.pendingCode = nil
                    Task { await partner.redeem(code: code) }
                }
                .buttonStyle(GoldButton())

                Button("Не сейчас") { partner.pendingCode = nil }
                    .buttonStyle(StoneButton())
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.large])
        .presentationBackground(Palette.obsidian)
        .onAppear { nicknameDraft = partner.nickname }
    }
}

// MARK: - Сквад

private struct SquadJoinSheet: View {

    @Environment(SquadManager.self) private var squad
    @Environment(PartnerManager.self) private var partner

    var body: some View {
        let code = squad.pendingCode ?? ""
        let title: LocalizedStringResource = squad.pendingInviter.map { "\($0) зовёт тебя в сквад" }
            ?? "Тебя зовут в сквад"

        VStack(spacing: 20) {
            JoinHeader(title: title,
                       note: "Участники увидят твоё прозвище «\(partner.nickname)», число дней и отметился ли ты сегодня. Календарь и срывы останутся только у тебя.")

            JoinCode(code: code)

            VStack(spacing: 12) {
                Button("Вступить") {
                    squad.pendingCode = nil
                    Task { await squad.join(code: code) }
                }
                .buttonStyle(GoldButton())

                Button("Не сейчас") { squad.pendingCode = nil }
                    .buttonStyle(StoneButton())
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.large])
        .presentationBackground(Palette.obsidian)
    }
}

// MARK: - Общие части

private struct JoinHeader: View {
    let title: LocalizedStringResource
    let note: LocalizedStringResource

    var body: some View {
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
        .padding(.top, 28)
    }
}

private struct JoinCode: View {
    let code: String

    var body: some View {
        Text(PartnerInvite(code: code, expiresAt: .distantFuture).grouped)
            .font(Face.display(32, .semibold))
            .tracking(4)
            .foregroundStyle(.goldFill)
    }
}
