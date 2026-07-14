import SwiftUI
import UIKit

/// A UIViewRepresentable text field that wraps UITextField with explicit
/// first responder activation. This bypasses SwiftUI's responder chain
/// issues that can prevent the keyboard from appearing.
struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var autocorrectionType: UITextAutocorrectionType = .no
    var returnKeyType: UIReturnKeyType = .default
    var font: UIFont?
    var textAlignment: NSTextAlignment = .natural
    var textColor: UIColor?
    var backgroundColor: UIColor?
    var cornerRadius: CGFloat = 0
    var borderColor: UIColor?
    var borderWidth: CGFloat = 0
    var leftPadding: CGFloat = 0
    var onReturn: (() -> Void)?
    var shouldBecomeFirstResponder: Bool = true

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.isSecureTextEntry = isSecure
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType
        textField.returnKeyType = returnKeyType
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.translatesAutoresizingMaskIntoConstraints = false

        if let font = font {
            textField.font = font
        }
        if let textColor = textColor {
            textField.textColor = textColor
        }
        if let backgroundColor = backgroundColor {
            textField.backgroundColor = backgroundColor
        }
        if let borderColor = borderColor {
            textField.layer.borderColor = borderColor.cgColor
        }
        textField.layer.cornerRadius = cornerRadius
        textField.layer.borderWidth = borderWidth

        if leftPadding > 0 {
            let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: leftPadding, height: 0))
            textField.leftView = paddingView
            textField.leftViewMode = .always
        }

        textField.textAlignment = textAlignment

        // Ensure the text field can become first responder
        textField.isUserInteractionEnabled = true

        // Make it first responder on appear
        if shouldBecomeFirstResponder {
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
        }

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onReturn: onReturn)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onReturn: (() -> Void)?

        init(text: Binding<String>, onReturn: (() -> Void)?) {
            self._text = text
            self.onReturn = onReturn
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.text = textField.text ?? ""
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onReturn?()
            return true
        }
    }
}