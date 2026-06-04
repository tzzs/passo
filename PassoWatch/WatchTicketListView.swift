import SwiftUI

/// The Watch's root screen: a list of the active tickets received from the
/// iPhone. Tapping a row pushes the on-wrist barcode detail.
struct WatchTicketListView: View {
    @EnvironmentObject private var receiver: WatchConnectivityReceiver

    var body: some View {
        NavigationStack {
            Group {
                if receiver.tickets.isEmpty {
                    emptyState
                } else {
                    List(receiver.tickets) { ticket in
                        NavigationLink(value: ticket) {
                            WatchTicketRow(ticket: ticket)
                        }
                    }
                    .navigationDestination(for: TicketDTO.self) { ticket in
                        WatchBarcodeDetailView(ticket: ticket)
                    }
                }
            }
            .navigationTitle("票据")
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "ticket")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("暂无票据")
                .font(.headline)
            Text("在 iPhone 上打开 Passo\n即可同步")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Row

struct WatchTicketRow: View {
    let ticket: TicketDTO

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(ticket.ticketType.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.title.isEmpty ? ticket.ticketType.displayName : ticket.title)
                    .font(.headline)
                    .lineLimit(1)
                if !ticket.eventTime.isEmpty {
                    Text(ticket.eventTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !ticket.venue.isEmpty {
                    Text(ticket.venue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

#Preview("List") {
    let receiver = WatchConnectivityReceiver()
    return WatchTicketListView()
        .environmentObject(receiver)
}
