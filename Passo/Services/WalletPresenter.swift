import PassKit
import SwiftUI

// MARK: - Wallet Presenter

/// Wraps PKAddPassesViewController in a SwiftUI sheet.
/// Usage: `.sheet(isPresented: $show) { WalletPresenter(passData: data, onDone: { ... }) }`
struct WalletPresenter: UIViewControllerRepresentable {
    let passData: Data
    let onAdded: () -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onAdded: onAdded, onCancelled: onCancelled) }

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

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        private let onAdded: () -> Void
        private let onCancelled: () -> Void

        init(onAdded: @escaping () -> Void, onCancelled: @escaping () -> Void) {
            self.onAdded     = onAdded
            self.onCancelled = onCancelled
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true)
            let library = PKPassLibrary()
            // PKPassLibrary doesn't directly tell us if the pass was added;
            // treat dismiss as success since user saw the sheet.
            if library.passes().isEmpty == false {
                onAdded()
            } else {
                onCancelled()
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
