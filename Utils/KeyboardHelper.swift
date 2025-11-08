import SwiftUI

extension View {
    /// Dismisses the keyboard when the view is tapped outside a text input.
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
    
    /// Hides the keyboard by resigning first responder.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
