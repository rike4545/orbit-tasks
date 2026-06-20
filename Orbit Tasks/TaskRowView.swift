import SwiftUI

struct TaskRowView: View {
    @Environment(\.editMode) private var editMode

    let task: OrbitTask
    let onToggleDone: () -> Void
    let onOpen: (() -> Void)?

    init(task: OrbitTask, onToggleDone: @escaping () -> Void, onOpen: (() -> Void)? = nil) {
        self.task = task
        self.onToggleDone = onToggleDone
        self.onOpen = onOpen
    }

    private var isSelecting: Bool {
        (editMode?.wrappedValue.isEditing ?? false)
    }

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: "circle")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } else {
                Button(action: onToggleDone) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark task incomplete" : "Mark task complete")
            }

            if let onOpen {
                Button(action: onOpen) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var rowContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .fontDesign(.rounded)
                    .strikethrough(task.isCompleted, color: .secondary)

                HStack(spacing: 8) {
                    if let s = task.scheduledAt {
                        metaPill(DateHelpers.compactDateTimeString(s), systemImage: "clock")
                    }

                    if task.isEvening, let scheduledAt = task.scheduledAt, DateHelpers.isToday(scheduledAt) {
                        metaPill("Evening", systemImage: "moon.stars")
                    }

                    if let d = task.deadlineAt {
                        metaPill(DateHelpers.relativeDayString(d), systemImage: "flag")
                    }

                    if task.priority != .none {
                        metaPill(task.priority.label, systemImage: "exclamationmark")
                    }

                    if let progress = task.checklistProgressText {
                        metaPill(progress, systemImage: "checklist")
                    }
                }
            }

            Spacer()

            if task.attachments.count > 0 {
                Image(systemName: "paperclip")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func metaPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08), in: Capsule(style: .continuous))
    }
}
