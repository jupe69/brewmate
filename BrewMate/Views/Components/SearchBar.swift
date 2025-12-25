import SwiftUI

/// A native-looking search bar component
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Focus the search bar (useful for keyboard shortcuts)
    func focus() {
        isFocused = true
    }
}

/// A search bar specifically styled for the toolbar
struct ToolbarSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search packages"

    var body: some View {
        SearchBar(text: $text, placeholder: placeholder)
            .frame(minWidth: 180, maxWidth: 300)
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""), placeholder: "Search formulae...")
        SearchBar(text: .constant("nginx"), placeholder: "Search formulae...")
    }
    .padding()
    .frame(width: 300)
}
