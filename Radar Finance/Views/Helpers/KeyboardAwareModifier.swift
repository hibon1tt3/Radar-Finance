import SwiftUI
import Combine

struct KeyboardAwareModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(KeyboardHeightReader(height: $keyboardHeight))
            .padding(.bottom, keyboardHeight)
    }
}

private struct KeyboardHeightReader: UIViewControllerRepresentable {
    @Binding var height: CGFloat
    
    func makeUIViewController(context: Context) -> KeyboardViewController {
        let vc = KeyboardViewController()
        vc.heightDidChange = { [weak vc] height in
            guard vc != nil else { return }
            self.height = height
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: KeyboardViewController, context: Context) {
    }
}

private class KeyboardViewController: UIViewController {
    var heightDidChange: ((CGFloat) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        
        UIView.animate(withDuration: duration) {
            self.heightDidChange?(keyboardHeight)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        
        UIView.animate(withDuration: duration) {
            self.heightDidChange?(0)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension View {
    func keyboardAware() -> some View {
        modifier(KeyboardAwareModifier())
    }
} 