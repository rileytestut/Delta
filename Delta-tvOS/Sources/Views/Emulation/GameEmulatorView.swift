import SwiftUI

struct GameEmulatorView: UIViewControllerRepresentable {
    let game: TVGame
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> GameEmulatorViewController {
        let vc = GameEmulatorViewController(game: game)
        vc.onDismiss = {
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: GameEmulatorViewController, context: Context) {
    }
}
