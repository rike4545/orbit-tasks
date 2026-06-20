import SwiftUI
import SwiftData

struct BrowseView: View {
    private enum BrowseSheet: Identifiable {
        case area
        case project
        case tag

        var id: Self { self }
    }

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\OrbitArea.name, order: .forward)])
    private var areas: [OrbitArea]

    @Query(sort: [SortDescriptor(\OrbitProject.name, order: .forward)])
    private var projects: [OrbitProject]

    @Query(sort: [SortDescriptor(\OrbitTag.name, order: .forward)])
    private var tags: [OrbitTag]

    @Query(sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)])
    private var allTasks: [OrbitTask]

    @State private var activeSheet: BrowseSheet?

    private var openTasks: [OrbitTask] {
        allTasks.filter { !$0.isCompleted }
    }

    private var anytimeCount: Int {
        openTasks.filter { $0.scheduledAt == nil && $0.listOverride != .someday }.count
    }

    private var somedayCount: Int {
        openTasks.filter { $0.scheduledAt == nil && $0.listOverride == .someday }.count
    }

    private var logbookCount: Int {
        allTasks.filter(\.isCompleted).count
    }

    var body: some View {
        List {
            Section(L10n.string("browse.section.lists")) {
                NavigationLink {
                    AnytimeView()
                } label: {
                    listRow(title: L10n.string("browse.anytime"), systemImage: "tray.and.arrow.down", count: anytimeCount)
                }

                NavigationLink {
                    SomedayView()
                } label: {
                    listRow(title: L10n.string("browse.someday"), systemImage: "archivebox", count: somedayCount)
                }

                NavigationLink {
                    LogbookView()
                } label: {
                    listRow(title: L10n.string("browse.logbook"), systemImage: "checkmark.circle", count: logbookCount)
                }
            }

            Section(L10n.string("browse.section.areas")) {
                if areas.isEmpty {
                    Text(L10n.string("browse.empty.areas"))
                        .foregroundStyle(.secondary)
                }
                ForEach(areas) { area in
                    NavigationLink {
                        AreaDetailView(area: area)
                    } label: {
                        areaRow(area)
                    }
                }
            }

            Section(L10n.string("browse.section.projects")) {
                if projects.isEmpty {
                    Text(L10n.string("browse.empty.projects"))
                        .foregroundStyle(.secondary)
                }
                ForEach(projects) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        projectRow(project)
                    }
                }
            }

            Section(L10n.string("browse.section.tags")) {
                if tags.isEmpty {
                    Text(L10n.string("browse.empty.tags"))
                        .foregroundStyle(.secondary)
                }
                ForEach(tags) { tag in
                    NavigationLink {
                        TagDetailView(tag: tag)
                    } label: {
                        HStack {
                            Text(tag.name)
                            Spacer()
                            Text("\(tag.tasks.filter { !$0.isCompleted }.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.string("nav.browse"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L10n.string("browse.new.area")) { activeSheet = .area }
                    Button(L10n.string("browse.new.project")) { activeSheet = .project }
                    Button(L10n.string("browse.new.tag")) { activeSheet = .tag }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .area:
                AreaEditorSheet()
            case .project:
                ProjectEditorSheet()
            case .tag:
                TagEditorSheet()
            }
        }
        .orbitBannerPlacement()
    }

    private func projectOpenTaskCount(_ project: OrbitProject) -> Int {
        openTasks.filter { $0.project?.id == project.id }.count
    }

    private func areaOpenTaskCount(_ area: OrbitArea) -> Int {
        openTasks.filter { $0.project?.area?.id == area.id }.count
    }

    private func listRow(title: String, systemImage: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            countText(count)
        }
    }

    private func areaRow(_ area: OrbitArea) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(area.name)
                Text("\(area.projects.count) projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            countText(areaOpenTaskCount(area))
        }
    }

    private func projectRow(_ project: OrbitProject) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)

                HStack(spacing: 8) {
                    if let areaName = project.area?.name {
                        Text(areaName)
                    }

                    if let deadlineAt = project.deadlineAt {
                        Label(DateHelpers.relativeDayString(deadlineAt), systemImage: "flag")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
            countText(projectOpenTaskCount(project))
        }
    }

    private func countText(_ count: Int) -> some View {
        Text("\(count)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Detail Views

struct AreaDetailView: View {
    let area: OrbitArea
    @State private var showAddProject = false

    var body: some View {
        List {
            Section("Projects") {
                if area.projects.isEmpty {
                    Text("No projects in this area.")
                        .foregroundStyle(.secondary)
                }
                ForEach(area.projects.sorted(by: { $0.name < $1.name })) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        Text(project.name)
                    }
                }
            }
        }
        .navigationTitle(area.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddProject = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddProject) {
            ProjectEditorSheet(presetArea: area)
        }
    }
}

struct ProjectDetailView: View {
    private struct HeadingGroup: Identifiable {
        let id: String
        let title: String
        let tasks: [OrbitTask]
    }

    @Environment(\.modelContext) private var modelContext
    let project: OrbitProject

    @Query(
        filter: #Predicate<OrbitTask> { t in t.isCompleted == false },
        sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)]
    )
    private var openTasks: [OrbitTask]

    @Query(
        filter: #Predicate<OrbitTask> { t in t.isCompleted == true },
        sort: [SortDescriptor(\OrbitTask.completedAt, order: .reverse)]
    )
    private var completedTasks: [OrbitTask]

    @State private var showAddTask = false
    @State private var newTaskHeading: String? = nil
    @State private var showEditProject = false
    @State private var showCompleteProjectConfirmation = false

    private var tasks: [OrbitTask] {
        openTasks.filter { $0.project?.id == project.id }
            .sorted {
                let a = $0.scheduledAt ?? .distantFuture
                let b = $1.scheduledAt ?? .distantFuture
                if a != b { return a < b }
                return $0.createdAt < $1.createdAt
            }
    }

    private var completedProjectTasks: [OrbitTask] {
        completedTasks.filter { $0.project?.id == project.id }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    private var recentlyCompletedTasks: [OrbitTask] {
        Array(completedProjectTasks.prefix(5))
    }

    private var headingGroups: [HeadingGroup] {
        let grouped = Dictionary(grouping: tasks) { task in
            task.projectHeading?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        let keys = grouped.keys.sorted { lhs, rhs in
            if lhs.isEmpty { return false }
            if rhs.isEmpty { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return keys.map { key in
            HeadingGroup(
                id: key.isEmpty ? "__tasks" : key,
                title: key.isEmpty ? "Tasks" : key,
                tasks: grouped[key] ?? []
            )
        }
    }

    private var projectNotes: String {
        project.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            projectSummary

            if tasks.isEmpty {
                EmptyStateView(systemImage: "checklist", title: "No tasks", subtitle: "Add the next action.")
                    .listRowSeparator(.hidden)
            } else {
                ForEach(headingGroups) { group in
                    Section {
                        ForEach(group.tasks) { task in
                            TaskRowView(task: task, onToggleDone: { toggleDone(task) }, onOpen: {
                                TaskEditorCoordinator.shared.present(task: task)
                            })
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(task) } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Button {
                                newTaskHeading = group.id == "__tasks" ? nil : group.title
                                showAddTask = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .imageScale(.medium)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Add task to \(group.title)")
                        }
                    }
                }
            }

            if !completedProjectTasks.isEmpty {
                Section {
                    ForEach(recentlyCompletedTasks) { task in
                        TaskRowView(task: task, onToggleDone: { reopen(task) }, onOpen: {
                            TaskEditorCoordinator.shared.present(task: task)
                        })
                        .swipeActions(edge: .leading) {
                            Button { reopen(task) } label: {
                                Label("Reopen", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        }
                    }

                    if completedProjectTasks.count > recentlyCompletedTasks.count {
                        Text("\(completedProjectTasks.count - recentlyCompletedTasks.count) more completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(completedProjectTasks.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newTaskHeading = nil
                        showAddTask = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }

                    Button {
                        showEditProject = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }

                    if !tasks.isEmpty {
                        Button {
                            showCompleteProjectConfirmation = true
                        } label: {
                            Label("Complete Project", systemImage: "checkmark.seal")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            TaskEditorSheet(mode: .create(initialBucket: .project(project, heading: newTaskHeading)))
        }
        .sheet(isPresented: $showEditProject) {
            ProjectEditorSheet(project: project)
        }
        .confirmationDialog(
            "Complete Project?",
            isPresented: $showCompleteProjectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Complete \(tasks.count) Open Tasks") {
                completeProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This marks every open task in \(project.name) as complete.")
        }
    }

    private var projectSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !projectNotes.isEmpty {
                Text(projectNotes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                OrbitStatPill(label: "open", value: "\(tasks.count)", systemImage: "checklist")
                OrbitStatPill(label: "done", value: "\(completedProjectTasks.count)", systemImage: "checkmark.circle")

                if let deadlineAt = project.deadlineAt {
                    OrbitStatPill(label: "deadline", value: DateHelpers.dayString(deadlineAt), systemImage: "flag")
                }
            }
        }
        .orbitCardStyle()
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func toggleDone(_ task: OrbitTask) {
        TaskCompletionEngine.complete(task, in: modelContext)
    }

    private func delete(_ task: OrbitTask) {
        NotificationManager.shared.cancelReminder(for: task.id)
        modelContext.delete(task)
        try? modelContext.save()
    }

    private func completeProject() {
        let openProjectTasks = tasks
        for task in openProjectTasks {
            TaskCompletionEngine.complete(task, in: modelContext)
        }
    }

    private func reopen(_ task: OrbitTask) {
        task.isCompleted = false
        task.completedAt = nil
        task.touch()
        try? modelContext.save()
        TaskHaptics.light()
    }
}

struct TagDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let tag: OrbitTag

    private var openTasks: [OrbitTask] {
        tag.tasks.filter { !$0.isCompleted }
            .sorted {
                let a = $0.scheduledAt ?? .distantFuture
                let b = $1.scheduledAt ?? .distantFuture
                if a != b { return a < b }
                return $0.createdAt < $1.createdAt
            }
    }

    var body: some View {
        List {
            if openTasks.isEmpty {
                EmptyStateView(systemImage: "tag", title: "No tasks", subtitle: "Nothing currently tagged \(tag.name).")
                    .listRowSeparator(.hidden)
            } else {
                ForEach(openTasks) { task in
                    TaskRowView(task: task, onToggleDone: { toggleDone(task) }, onOpen: {
                        TaskEditorCoordinator.shared.present(task: task)
                    })
                }
            }
        }
        .navigationTitle("#\(tag.name)")
    }

    private func toggleDone(_ task: OrbitTask) {
        task.isCompleted = true
        task.completedAt = Date()
        task.touch()
        try? modelContext.save()
        NotificationManager.shared.cancelReminder(for: task.id)
        TaskHaptics.success()
        OrbitInterstitialAdManager.shared.recordTaskCompletionEvent()
    }
}
