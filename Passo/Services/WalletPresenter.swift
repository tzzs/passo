import PassKit
import SwiftUI

// MARK: - Wallet Presenter

/// Wraps PKAddPassesViewController in a SwiftUI sheet.
/// Usage: `.sheet(isPresented: $show) { WalletPresenter(passData: data, onDone: { ... }) }`
struct WalletPresenter: UIViewControllerRepresentable {
    let passData: Data
    let onAdded: () -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        let pass = try? PKPass(data: passData)
        return Coordinator(pass: pass, onAdded: onAdded, onCancelled: onCancelled)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        guard PKPassLibrary.isPassLibraryAvailable() else {
            return UIViewController()  // Simulator: no Wallet
        }
        guard
            let pass = try? PKPass(data: passData),
            let vc   = PKAddPassesViewController(pass: pass)
        else {
            return UIViewController()
        }
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, @preconcurrency PKAddPassesViewControllerDelegate {
        private let onAdded: () -> Void
        private let onCancelled: () -> Void
        private var pass: PKPass?

        init(pass: PKPass?, onAdded: @escaping () -> Void, onCancelled: @escaping () -> Void) {
            self.pass        = pass
            self.onAdded     = onAdded
            self.onCancelled = onCancelled
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true)
            // PKPassLibrary may not reflect the just-added pass synchronously,
            // so give it a beat before the membership check to avoid a false
            // "cancelled" right after a successful add.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                if let pass = self.pass, PKPassLibrary().containsPass(pass) {
                    self.onAdded()
                } else {
                    self.onCancelled()
                }
            }
        }
    }
}

// MARK: - Open Wallet App

extension UIApplication {
    /// Opens the system Wallet app. Falls back to Settings if Wallet is unavailable.
    func openWallet() {
        let walletURL = URL(string: "shoebox://")!
        if canOpenURL(walletURL) {
            open(walletURL)
        }
    }
}
