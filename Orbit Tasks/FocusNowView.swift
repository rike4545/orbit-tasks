import SwiftUI
import SwiftData
import Combine

struct FocusNowView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)])
    private var allTasks: [OrbitTask]

    @State private var selectedID: UUID? = nil
    @State private var now: Date = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var openTasks: [OrbitTask] {
        allTasks.filter { !$0.isCompleted && !$0.isPrivate }
    }

    private var selectedTask: OrbitTask? {
        guard let id = selectedID else { return nil }
        return openTasks.first(where: { $0.id == id })
    }

    var body: some View {
        List {
            Section("Now") {
                if let task = selectedTask {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title).font(.headline)

                        if let started = task.timerStartedAt {
                            Text(elapsedString(since: started, now: now))
                                .font(.system(.title2, design: .rounded).monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not running").foregroundStyle(.secondary)
                        }

                        HStack {
                            Button(task.isTimerRunning ? "Stop" : "Start") {
                                if task.isTimerRunning {
                                    task.stopTimer()
                                } else {
                                    task.startTimer()
                                    TaskHaptics.light()
                                }
                                task.touch()
                                try? modelContext.save()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Complete") {
                                TaskCompletionEngine.complete(task, in: modelContext)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Pick a task below to focus.").foregroundStyle(.secondary)
                }
            }

            Section("Pick a task") {
                ForEach(openTasks) { t in
                    Button {
                        selectedID = t.id
                        TaskHaptics.light()
                    } label: {
                        HStack {
                            Text(t.title).lineLimit(1)
                            Spacer()
                            if t.id == selectedID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                            if t.isTimerRunning {
                                Image(systemName: "timer")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Focus")
        .onReceive(ticker) { dt in
            now = dt
        }
    }

    private func elapsedString(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
