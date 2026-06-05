import SwiftUI
import UIKit

/// Shows a single ticket's scannable barcode. The image is pre-rendered on the
/// iPhone (watchOS has no CoreImage) and shipped over WatchConnectivity; the
/// Watch just displays it on a white plate so scanners get clean contrast.
struct WatchBarcodeDetailView: View {
    let ticket: TicketDTO

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                VStack(spacing: 2) {
                    Text(ticket.title.isEmpty ? ticket.ticketType.displayName : ticket.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    if !ticket.eventTime.isEmpty {
                        Text(ticket.eventTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                barcode

                if !ticket.venue.isEmpty {
                    Text(ticket.venue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .navigationTitle(ticket.ticketType.displayName)
    }

    /// Linear (1D) codes render as a short wide strip; matrix codes render square.
    private var isLinear: Bool {
        let f = ticket.barcodeFormat
        return f != "QR" && f != "DataMatrix" && f != "Aztec"
    }

    @ViewBuilder
    private var barcode: some View {
        if let data = ticket.barcodeImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: isLinear ? 70 : 150)
                .padding(AppSpacing.sm)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
        } else {
            RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
                .fill(.gray.opacity(0.2))
                .frame(height: 120)
                .overlay {
                    Text("无条码")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#Preview("Detail") {
    NavigationStack {
        WatchBarcodeDetailView(
            ticket: TicketDTO(
                id: "1",
                title: "奥本海默",
                venue: "万达影城 · 来福士店",
                eventTime: "19:30",
                eventDate: Date(),
                barcodeValue: "89012345678901234",
                barcodeFormat: "QR",
                typeRaw: TicketType.movie.rawValue
            )
        )
    }
}
