// bible-reader/NoteEditorView.swift
import SwiftUI

/// Modal editor for a single verse's note. Calls `onSave` with the edited text;
/// the caller is responsible for persisting (blank body deletes the note).
struct NoteEditorView: View {
    let reference: Reference
    let bookName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(reference: Reference, bookName: String, existingBody: String, onSave: @escaping (String) -> Void) {
        self.reference = reference
        self.bookName = bookName
        self.onSave = onSave
        _text = State(initialValue: existingBody)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle(reference.displayString(bookName: bookName))
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            onSave(text)
                            dismiss()
                        }
                    }
                }
        }
    }
}
