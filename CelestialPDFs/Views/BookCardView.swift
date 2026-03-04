//
//  BookCardView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct BookCardView: View {
    @Environment(BookStore.self) private var store
    let book: PDFBook

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover - auto-cropped via BookStore.thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(
                        color: .black.opacity(isHovered ? 0.25 : 0.12),
                        radius: isHovered ? 10 : 4,
                        x: 0,
                        y: isHovered ? 6 : 2
                    )

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    // Placeholder cover
                    VStack(spacing: 8) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text(book.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 8)
                    }
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )

            // Title
            Text(book.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .truncationMode(.tail)

            // Author
            if !book.author.isEmpty {
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Tags
            if !book.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(book.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tagColor(for: tag).opacity(0.15))
                            .foregroundStyle(tagColor(for: tag))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(8)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            // Thumbnail with auto-cropping handled in BookStore
            thumbnail = store.thumbnail(for: book)
        }
    }

    private func tagColor(for tag: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan, .indigo, .mint]
        let hash = abs(tag.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
            totalHeight = max(totalHeight, y + rowHeight)
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}
