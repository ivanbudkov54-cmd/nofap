//
//  RemoteArticleList.swift
//  NoFap
//
//  Статьи из knowledge_articles. Если выборка пустая, вкладки остаются
//  на локальном моке — это запасной путь без сети и до первой публикации.
//

import SwiftUI

struct RemoteArticleList: View {
    let articles: [KnowledgeArticle]
    var proReason: String? = nil
    /// Сколько первых статей открыто без Pro, если список платный.
    var freeCount = 3

    @Environment(PremiumStore.self) private var subscriptions
    @State private var opened: KnowledgeArticle?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                    let locked = proReason != nil && index >= freeCount
                    Button {
                        open(article, locked: locked)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.marbleHigh)
                                .multilineTextAlignment(.leading)
                            if let description = article.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.ash)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .cardSurface()
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        if locked && !subscriptions.isPro {
                            ProLockBadge()
                                .padding(10)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .navigationDestination(item: $opened) { article in
            RemoteArticlePage(article: article)
        }
    }

    private func open(_ article: KnowledgeArticle, locked: Bool) {
        if locked, let proReason {
            subscriptions.checkProAccess(for: proReason) { opened = article }
        } else {
            opened = article
        }
    }
}

struct RemoteArticlePage: View {
    let article: KnowledgeArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = article.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let content = article.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.marble)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ArticleStudiedBar(articleID: article.id.uuidString, isScience: article.tabType == "deep_dive")
            }
            .padding(20)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
