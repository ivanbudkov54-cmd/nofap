//
//  DeepDiveView.swift
//  NoFap
//
//  Вкладка «Deep Dive» — статьи и гайды с фильтром по категориям.
//

import SwiftUI

struct DeepDiveView: View {

    @Environment(Backend.self) private var backend
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var selectedCategory: DeepDiveCategory?
    @State private var openedArticle: Article?

    private var filtered: [Article] {
        guard let selectedCategory else { return ArticleLibrary.all }
        return ArticleLibrary.all.filter { $0.category == selectedCategory }
    }

    var body: some View {
        let remote = backend.articles(tab: "deep_dive")
        if remote.isEmpty {
            localBody
        } else {
            RemoteArticleList(articles: remote)
        }
    }

    private var localBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                categoryChips

                VStack(spacing: 12) {
                    ForEach(filtered) { article in
                        Button {
                            open(article)
                        } label: {
                            row(article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .navigationDestination(item: $openedArticle) { article in
            ArticleDetailView(article: article)
        }
    }

    private func open(_ article: Article) {
        let reason = "Научные исследования и механизмы работы мозга доступны подписчикам Pro"
        if article.category != .neuroscience {
            openedArticle = article
        } else {
            subscriptions.checkProAccess(for: reason) { openedArticle = article }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Все", isSelected: selectedCategory == nil) {
                    withAnimation(.snappy(duration: 0.2)) { selectedCategory = nil }
                }
                ForEach(DeepDiveCategory.allCases) { category in
                    chip(title: category.rawValue, isSelected: selectedCategory == category) {
                        withAnimation(.snappy(duration: 0.2)) { selectedCategory = category }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color(hex: 0x1A1405) : Palette.marble)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule().fill(.goldFill)
                    } else {
                        Capsule().fill(Palette.basalt)
                            .overlay { Capsule().strokeBorder(Palette.vein, lineWidth: 1) }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func row(_ article: Article) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: article.icon)
                .font(.system(size: 17))
                .foregroundStyle(.goldFill)
                .frame(width: 42, height: 42)
                .background(Palette.gold.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.leading)

                Text(article.excerpt)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(article.category.rawValue)
                    Text("·")
                    Text(article.readTime)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.gold)
                .padding(.top, 2)
            }

            if article.category == .neuroscience && !subscriptions.isPro {
                ProLockBadge()
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ash)
        }
        .padding(16)
        .cardSurface()
    }
}
