//
//  ManifestDecisionView.swift
//  NoFap
//
//  Последний экран квиза: человек сам выбирает путь. Отказ сворачивает
//  приложение на домашний экран; при возврате выбор снова перед ним.
//

import SwiftUI
import UIKit

struct ManifestDecisionView: View {

    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.goldFill)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)

                    Text("Твой скрытый ресурс: перенаправление энергии")
                        .font(Face.display(26, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Каждый срыв истощает дофаминовые рецепторы, притупляя вкус к реальной жизни, амбиции и остроту эмоций.")
                        Text("Воздержание — это не запрет, а трансмутация. Сохраняя внутреннюю энергию, ты восстанавливаешь естественный уровень тестостерона, возвращаешь уверенность во взгляде, стальной фокус и драйв побеждать.")
                        Text("Ты здесь, чтобы подчинить инстинкты своей воле.")
                            .foregroundStyle(Palette.gold)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.marble)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                Button("Готов изменить себя", action: onAccept)
                    .buttonStyle(GoldButton())

                Button("Остаться в серой реальности", action: leaveApp)
                    .buttonStyle(StoneButton())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .background(Palette.obsidian.ignoresSafeArea())
    }

    private func leaveApp() {
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
    }
}
