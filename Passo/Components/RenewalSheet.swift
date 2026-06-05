import SwiftUI

// MARK: - Renewal Sheet

/// Lets the user pick a new validity date for an expired ticket or card.
///
/// This is a pure presentation component: it owns only the in-flight date
/// selection and hands the chosen date back through `onRenew`. Persistence
/// (`ticket.renew(until:)` + `modelContext.save()` + reminder rescheduling)
/// stays at the call site, keeping this file free of persistence logic per the
/// `Components/` directory convention.
struct RenewalSheet: View {
    let ticket: Ticket
    let onRenew: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(ticket: Ticket, onRenew: @escaping (Date) -> Void) {
        self.ticket = ticket
        self.onRenew = onRenew
        // Seed with the per-type suggestion the user defined in
        // Ticket.suggestedRenewalDate(for:).
        _selectedDate = State(initialValue: Ticket.suggestedRenewalDate(for: ticket.ticketType))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "选择新的有效期",
                        selection: $selectedDate,
                        in: Date()...,                 // Renewal must land in the future
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                } header: {
                    HStack(spacing: 8) {
                        Text(ticket.ticketType.emoji)
                        Text(ticket.title.isEmpty ? "未识别票据" : ticket.title)
                            .lineLimit(1)
                    }
                }
            }
            .navigationTitle("选择新的有效期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("续期") {
                        onRenew(selectedDate)
                        dismiss()
                    }
                }
            }
        }
    }
}
