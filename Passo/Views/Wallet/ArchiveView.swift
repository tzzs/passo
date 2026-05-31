import SwiftUI
import SwiftData

// MARK: - Archive View (已归档)

/// Unified archive for everything no longer active — expired/used tickets AND
/// expired cards. Pushed from the 票据 tab. Supports restore and delete.
struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme

    @Query(sort: \Ticket.importedAt, order: .reverse) private var tickets: [Ticket]

    private var isDark: Bool { colorScheme == .dark }

    private var archived: [Ticket] {
        tickets
            .filter(\.isInArchive)
            .sorted { ($0.archivedAt ?? $0.importedAt) > ($1.archivedAt ?? $1.importedAt) }
    }

    var body: some View {
        Group {
            if archived.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(archived) { ticket in
                        NavigationLink {
                            PassDetailView(ticket: ticket)
                        } label: {
                            row(ticket)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { delete(ticket) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            // Restore only when it would actually leave the archive.
                            // Auto-expired items can't be un-expired, so no restore.
                            if ticket.canRestore {
                                Button { restore(ticket) } label: {
                                    Label("恢复", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("已归档")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Row

    private func row(_ ticket: Ticket) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(ticket.ticketType.theme.accent.opacity(isDark ? 0.2 : 0.12))
                    .frame(width: 38, height: 38)
                Text(ticket.ticketType.emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.title.isEmpty ? "未识别票据" : ticket.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                    .lineLimit(1)
                let detail = [ticket.eventTime, ticket.venue]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            reasonTag(ticket)
        }
        .padding(.vertical, 4)
        .saturation(0.5)
    }

    private func reasonTag(_ ticket: Ticket) -> some View {
        let (label, color): (String, Color) = {
            if ticket.isExpired { return ("已过期", Color(hex: "#A8A39A")) }
            if ticket.isUsed     { return ("已使用", Color(hex: "#8E8E93")) }
            return ("已归档", Color(hex: "#8E8E93"))
        }()
        return Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: Actions

    private func restore(_ ticket: Ticket) {
        ticket.isArchived = false
        ticket.isUsed     = false
        ticket.archivedAt = nil
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func delete(_ ticket: Ticket) {
        ReminderService.cancelReminder(ticketID: ticket.id)
        modelContext.delete(ticket)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("归档是空的")
                .font(.system(size: 18, weight: .semibold))
            Text("用过、过期的票和卡会自动收进这里")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Ticket.self, configurations: config)
    let used = Ticket.preview(.movie); used.isUsed = true
    container.mainContext.insert(used)
    return NavigationStack { ArchiveView() }
        .modelContainer(container)
}
