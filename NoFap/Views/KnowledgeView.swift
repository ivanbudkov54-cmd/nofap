//
//  KnowledgeView.swift
//  NoFap
//

import SwiftUI

struct KnowledgeView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                VStack(spacing: 14) {
                    ForEach(ArticleLibrary.all) { article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            row(article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Знания")
                .font(Face.display(28, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Text("Прокачивай разум. Понимай, что происходит на самом деле.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func row(_ article: Article) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.leading)
                Text(article.sourceName)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.gold)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ash)
        }
        .padding(16)
        .cardSurface()
    }
}
