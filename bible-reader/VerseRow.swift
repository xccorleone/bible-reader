// bible-reader/VerseRow.swift
import SwiftUI

/// One verse line: optional bookmark icon, verse number + text with optional
/// highlight background, optional note icon, and a selection border.
struct VerseRow: View {
    let verse: Verse
    let fontSize: Double
    let highlightHex: String?
    let isBookmarked: Bool
    let hasNote: Bool
    /// Secondary (parallel) translation text for this verse, shown beneath the
    /// primary line when `isParallel` is true. A nil value while parallel
    /// renders a faint placeholder (versification gap).
    let secondaryText: String?
    let isParallel: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onTapNote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            if isBookmarked {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: fontSize * 0.6))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                (Text("\(verse.number) ")
                    .font(.system(size: fontSize * 0.7))
                    .foregroundStyle(highlightHex != nil ? Color.black.opacity(0.5) : Color.secondary)
                 + Text(verse.text)
                    .font(.system(size: fontSize))
                    .foregroundStyle(highlightHex != nil ? Color.black : Color.primary))

                if isParallel {
                    Text(secondaryText ?? "—")
                        .font(.system(size: fontSize * 0.92))
                        .italic()
                        .foregroundStyle(highlightHex != nil ? Color.black.opacity(0.75)
                                                              : Color.secondary)
                }
            }
            if hasNote {
                Button(action: onTapNote) {
                    Image(systemName: "note.text")
                        .font(.system(size: fontSize * 0.6))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(highlightHex.map { Color(hex: $0) } ?? .clear)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
