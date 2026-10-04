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
                Eyebrow(verbatim: article.category.rawValue, color: Palette.gold)

                Text(article.title)
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.subtitle.isEmpty {
                    Text(article.subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if article.contentMarkdown.isEmpty {
                    Text(article.summary)
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.marble)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ArticleMarkdown(text: article.contentMarkdown)
                }

                sourceCard

                ArticleStudiedBar(
                    articleID: article.id,
                    isScience: article.category == .science || article.category == .neuroscience
                )
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

private struct ArticleMarkdown: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let line):
                    Text(line)
                        .font(Face.display(18, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                case .bullet(let line):
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(Palette.gold)
                        Text(inline(line))
                            .font(.system(size: 16))
                            .foregroundStyle(Palette.marble)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .paragraph(let line):
                    Text(inline(line))
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.marble)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private enum Block {
        case heading(String)
        case bullet(String)
        case paragraph(String)
    }

    private var blocks: [Block] {
        text.split(separator: "\n", omittingEmptySubsequences: false).compactMap { raw in
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("# ") { return nil }
            if line.hasPrefix("### ") {
                return .heading(String(line.dropFirst(4)))
            }
            if line.hasPrefix("* ") || line.hasPrefix("- ") {
                return .bullet(String(line.dropFirst(2)))
            }
            if let index = line.firstIndex(of: "."),
               line.distance(from: line.startIndex, to: index) <= 2,
               line.prefix(while: \.isNumber).count > 0 {
                let rest = line[line.index(after: index)...].trimmingCharacters(in: .whitespaces)
                return .bullet(String(rest))
            }
            return .paragraph(line)
        }
    }

    private func inline(_ line: String) -> AttributedString {
        (try? AttributedString(markdown: line)) ?? AttributedString(line)
    }
}
