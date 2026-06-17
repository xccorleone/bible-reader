// bible-reader/VerseSelectionToolbar.swift
import SwiftUI

/// Bottom action bar shown while one or more verses are selected.
/// Note is enabled only for a single selected verse.
struct VerseSelectionToolbar: View {
    let canAddNote: Bool
    let onBookmark: () -> Void
    let onHighlight: (String) -> Void
    let onNote: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBookmark) {
                Image(systemName: "bookmark")
            }
            ForEach(HighlightPalette.colors, id: \.self) { hex in
                Button {
                    onHighlight(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            Button(action: onNote) {
                Image(systemName: "note.text")
            }
            .disabled(!canAddNote)
            Spacer()
            Button("取消", action: onCancel)
        }
        .padding()
        .background(.bar)
    }
}
