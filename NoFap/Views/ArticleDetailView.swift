//
//  ArticleDetailView.swift
//  NoFap
//
//  Наш текст, не копия чужой статьи — короткое честное резюме плюс
//  явная ссылка на первоисточник, чтобы каждый мог сам всё проверить.
//

import SwiftUI

struct ArticleDetailView: View {

    let article: Article

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 8) {
                    Eyebrow(verbatim: article.category.rawValue, color: Palette.gold)
                    Text("·")
                        .foregroundStyle(Palette.ash)
                    Text(article.readTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.ash)
                }

                Text(article.title)
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)

                Text(article.summary)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.marble)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                sourceCard

                ArticleStudiedBar(articleID: article.id)
            }
            .padding(20)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sourceCard: some View {
        Button {
            openURL(article.url)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "источник")

                Text(article.sourceName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                Text(article.sourceDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)

                HStack(spacing: 6) {
                    Text("Открыть источник")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.goldFill)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}
