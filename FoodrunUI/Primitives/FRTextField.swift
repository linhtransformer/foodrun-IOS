import SwiftUI

// Themed text field. Select-all-on-focus for numeric keyboards
// (matches web `selectAllOnFocus` behavior).

public struct FRTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autoCapitalization: TextInputAutocapitalization = .never
    var isSecure: Bool = false

    @FocusState private var focused: Bool

    public init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autoCapitalization: TextInputAutocapitalization = .never,
        isSecure: Bool = false
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.keyboard = keyboard
        self.contentType = contentType
        self.autoCapitalization = autoCapitalization
        self.isSecure = isSecure
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FRSpacing.xs.value) {
            Text(label)
                .font(Font.foodrun.caption.weight(.medium))
                .foregroundStyle(Color.foodrun.mutedForeground)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(Font.foodrun.body)
            .foregroundStyle(Color.foodrun.foreground)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autoCapitalization)
            .autocorrectionDisabled(true)
            .focused($focused)
            .padding(.horizontal, FRSpacing.md.value)
            .padding(.vertical, FRSpacing.md.value)
            .background(
                RoundedRectangle(cornerRadius: FRRadius.row.value, style: .continuous)
                    .fill(Color.foodrun.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FRRadius.row.value, style: .continuous)
                    .stroke(focused ? Color.foodrun.foreground : Color.foodrun.border, lineWidth: focused ? 1.5 : 1)
            )
            .animation(FRAnimation.subtle, value: focused)
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    return FRTextField(
        "E-mail",
        text: $email,
        placeholder: "jij@foodrun.nl",
        keyboard: .emailAddress,
        contentType: .emailAddress
    )
    .padding()
    .background(Color.foodrun.background)
}
