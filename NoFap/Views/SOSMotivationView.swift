//
//  SOSMotivationView.swift
//  NoFap
//

import SwiftUI
import UIKit

struct SOSMotivationView: View {
    @State private var quotes = SOSQuoteManager()
    @State private var page = 0

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                ForEach(Array(SOSQuoteLibrary.all.enumerated()), id: \.element.id) { index, quote in
                    quoteCard(quote)
                        .tag(index)
                        .padding(.horizontal, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 250)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let next = quotes.getRandomQuote()
                if let index = SOSQuoteLibrary.all.firstIndex(of: next) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        page = index
                    }
                }
            } label: {
                Label("Следующая мысль", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.gold)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            if let index = SOSQuoteLibrary.all.firstIndex(of: quotes.current) {
                page = index
            }
        }
        .onChange(of: page) { _, newValue in
            quotes.show(SOSQuoteLibrary.all[newValue])
        }
    }

    private func quoteCard(_ quote: SOSQuote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                Spacer()
                Text(l10n: quote.tag)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.gold.opacity(0.16), in: Capsule())
            }

            Text(l10n: quote.text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)
                .id(quote.id)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

            HStack {
                Spacer()
                Text("— \(L10n.string(quote.author))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.ash)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1)
        }
    }
}
