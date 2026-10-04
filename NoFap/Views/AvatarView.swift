//
//  AvatarView.swift
//  NoFap
//

import SwiftUI
import UIKit

struct AvatarView: View {

    @Environment(AvatarProgressManager.self) private var progress
    @State private var breathe = false

    var body: some View {
        unlocked
    }

    private var unlocked: some View {
        ScrollView {
            VStack(spacing: 22) {
                rankHeader
                figure
                    .tourTarget(.avatar)
                experienceBar
                hall
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rankHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rankLine)
                .font(Face.display(24, .semibold))
                .foregroundStyle(Palette.gold)
                .fixedSize(horizontal: false, vertical: true)
            Text(l10n: progress.currentRank.summary)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var rankLine: String {
        String(format: L10n.string("Ранг %lld из 7 • %@"), progress.currentRank.rawValue, L10n.string(progress.currentRank.title))
    }

    private var figure: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.45))
                .frame(width: 160, height: 28)
                .blur(radius: 8)
                .offset(y: 132)
            SpartanFigureView(rank: progress.currentRank)
                .frame(height: 300)
                .scaleEffect(breathe ? 1.025 : 1)
                .offset(y: breathe ? -6 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 330)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private var experienceBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(progress.totalXP) / \(progress.nextLevelTargetXP) XP")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.marbleHigh)
                Spacer()
                if progress.nextRank == nil {
                    Text("Максимальный ранг")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.gold)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0x2A2A30))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: 0xF6D48A), Palette.gold, Color(hex: 0xC48A1A)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * CGFloat(progress.levelProgress)))
                }
            }
            .frame(height: 12)
            if progress.nextRank != nil {
                Text(String(format: L10n.string("До следующего ранга осталось: %lld XP"), progress.xpRemainingToNextLevel))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)
            }
        }
        .padding(14)
        .cardSurface()
        .animation(.easeInOut(duration: 0.45), value: progress.totalXP)
    }

    private var hall: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Зал славы")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SpartanRank.allCases) { rank in
                        SpartanHallCard(rank: rank, unlocked: rank <= progress.currentRank)
                            .frame(width: 220)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

struct SpartanFigureView: View {
    let rank: SpartanRank

    var body: some View {
        Group {
            if let image = UIImage(named: rank.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                procedural
            }
        }
    }

    private var procedural: some View {
        let bronze = Color(hex: UInt32(0x8C5A2B + rank.rawValue * 0x101008))
        return ZStack {
            Capsule()
                .fill(bronze)
                .frame(width: 18 + CGFloat(rank.rawValue), height: 86)
                .offset(x: -28, y: 78)
            Capsule()
                .fill(bronze)
                .frame(width: 18 + CGFloat(rank.rawValue), height: 86)
                .offset(x: 28, y: 78)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xF0BC4F), bronze], startPoint: .top, endPoint: .bottom))
                .frame(width: 64 + CGFloat(rank.rawValue) * 6, height: 120)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Palette.gold.opacity(0.35 + Double(rank.rawValue) * 0.08), lineWidth: 2)
                }
            Circle()
                .fill(Color(hex: 0xE7C99A))
                .frame(width: 54, height: 54)
                .offset(y: -86)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0xC48A1A))
                .frame(width: 62, height: 18)
                .offset(y: -108)
            Capsule()
                .fill(Palette.gold)
                .frame(width: 8, height: 16 + CGFloat(rank.rawValue) * 4)
                .offset(y: -124)
        }
    }
}

private struct SpartanHallCard: View {
    let rank: SpartanRank
    let unlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                SpartanFigureView(rank: rank)
                    .frame(height: 150)
                    .opacity(unlocked ? 1 : 0.15)
                    .overlay {
                        if !unlocked {
                            LinearGradient(colors: [Color.black.opacity(0.15), Color.black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Palette.marbleHigh)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            Text(l10n: rank.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(unlocked ? Palette.gold : Palette.ash)
                .lineLimit(2)
            Text(unlocked ? L10n.string(rank.summary) : String(format: L10n.string("Откроется на %lld XP"), rank.requiredXP))
                .font(.system(size: 12))
                .foregroundStyle(Palette.ash)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .cardSurface()
    }
}

struct SpartanLevelUpView: View {
    let rank: SpartanRank
    let onClose: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Palette.obsidian.ignoresSafeArea()
            ForEach(0..<14, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Palette.gold : Color(hex: 0xF6D48A))
                    .frame(width: 8, height: 8)
                    .offset(x: appear ? CGFloat((index - 7) * 18) : 0, y: appear ? CGFloat(-40 - (index % 5) * 28) : 40)
                    .opacity(appear ? 0.15 : 0.9)
            }
            VStack(spacing: 18) {
                Text("НОВЫЙ СПАРТАНСКИЙ РАНГ РАЗБЛОКИРОВАН!")
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.gold)
                    .multilineTextAlignment(.center)
                SpartanFigureView(rank: rank)
                    .frame(height: 260)
                    .scaleEffect(appear ? 1 : 0.72)
                    .shadow(color: Palette.gold.opacity(0.45), radius: appear ? 24 : 0)
                Text(l10n: rank.title)
                    .font(Face.display(22, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                Text(l10n: rank.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.marble)
                    .multilineTextAlignment(.center)
                Button(action: onClose) {
                    Text("Продолжить путь воина")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                appear = true
            }
        }
    }
}

struct ArticleStudiedBar: View {
    let articleID: String
    var isScience: Bool = false

    @Environment(AvatarProgressManager.self) private var progress
    @Environment(AvatarManager.self) private var avatar

    var body: some View {
        let studied = progress.hasReadArticle(id: articleID) || avatar.hasReadArticle(id: articleID)
        Button {
            progress.rewardArticleRead(articleId: articleID, isScience: isScience)
            avatar.addPowerForArticle(id: articleID)
        } label: {
            Text(studied ? "Уже изучена" : "Статья изучена")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(studied ? Palette.ash : Color(hex: 0x1A1405))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    studied ? AnyShapeStyle(Palette.vein) : AnyShapeStyle(Palette.gold),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .disabled(studied)
    }
}
