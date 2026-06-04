import SwiftUI

/// Shows a single ticket's scannable barcode, generated on-device. The barcode
/// sits on a white plate (so scanners get clean contrast) over the ticket type's
/// themed background.
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

    @ViewBuilder
    private var barcode: some View {
        if let image = WatchBarcodeGenerator.makeImage(value: ticket.barcodeValue,
                                                       format: ticket.barcodeFormat) {
            let linear = WatchBarcodeGenerator.isLinear(ticket.barcodeFormat)
            image
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: linear ? 70 : 150)
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
