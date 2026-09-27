import SwiftData
import SwiftUI

struct SearchView: View {
  @Environment(\.modelContext) private var modelContext

  @Query(sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)])
  private var allTasks: [OrbitTask]

  @Query(sort: [SortDescriptor(\OrbitArea.name, order: .forward)])
  private var areas: [OrbitArea]

  @Query(sort: [SortDescriptor(\OrbitProject.name, order: .forward)])
  private var projects: [OrbitProject]

  @Query(sort: [SortDescriptor(\OrbitTag.name, order: .forward)])
  private var tags: [OrbitTag]

  @State private var query: String = ""
  @State private var includeAttachments: Bool = true
  @State private var includeCompleted: Bool = false
  @State private var includePrivate: Bool = false

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var candidateTasks: [OrbitTask] {
    var tasks = includeCompleted ? allTasks : allTasks.filter { !$0.isCompleted }
    if !includePrivate { tasks = tasks.filter { !$0.isPrivate } }
    return tasks
  }

  private var results: [OrbitTask] {
    let q = trimmedQuery
    guard !q.isEmpty else { return [] }

    var out: [OrbitTask] = []
    out.reserveCapacity(40)

    for task in candidateTasks {
      if matches(task: task, q: q) {
        out.append(task)
        if out.count >= 200 { break }  // safety cap
      }
    }
    return out
  }

  private var projectResults: [OrbitProject] {
    let q = trimmedQuery
    guard !q.isEmpty else { return [] }
    return projects.filter {
      $0.name.localizedCaseInsensitiveContains(q) || $0.notes.localizedCaseInsensitiveContains(q)
        || ($0.area?.name.localizedCaseInsensitiveContains(q) ?? false)
    }
  }

  private var areaResults: [OrbitArea] {
    let q = trimmedQuery
    guard !q.isEmpty else { return [] }
    return areas.filter { $0.name.localizedCaseInsensitiveContains(q) }
  }

  private var tagResults: [OrbitTag] {
    let q = trimmedQuery
    guard !q.isEmpty else { return [] }
    return tags.filter { $0.name.localizedCaseInsensitiveContains(q) }
  }

  private var hasAnyResults: Bool {
    !results.isEmpty || !projectResults.isEmpty || !areaResults.isEmpty || !tagResults.isEmpty
  }

  private func matches(task: OrbitTask, q: String) -> Bool {
    if task.title.localizedCaseInsensitiveContains(q) { return true }
    if task.notes.localizedCaseInsensitiveContains(q) { return true }

    guard includeAttachments else { return false }

    for att in task.attachments {
      if att.displayName.localizedCaseInsensitiveContains(q) { return true }
      if att.uti.localizedCaseInsensitiveContains(q) { return true }
      if let t = att.indexedText, t.localizedCaseInsensitiveContains(q) { return true }
    }
    return false
  }

  var body: some View {
    List {
      if trimmedQuery.isEmpty {
        EmptyStateView(
          systemImage: "magnifyingglass",
          title: L10n.string("search.empty.title"),
          subtitle: includeAttachments
            ? L10n.string("search.empty.subtitle.attachments")
            : L10n.string("search.empty.subtitle.basic")
        )
        .listRowSeparator(.hidden)

      } else if !hasAnyResults {
        EmptyStateView(
          systemImage: "xmark.circle",
          title: L10n.string("search.no_results.title"),
          subtitle: L10n.string("search.no_results.subtitle")
        )
        .listRowSeparator(.hidden)

      } else {
        if !projectResults.isEmpty {
          Section(L10n.string("search.section.projects")) {
            ForEach(projectResults) { project in
              NavigationLink {
                ProjectDetailView(project: project)
              } label: {
                VStack(alignment: .leading, spacing: 2) {
                  Label(project.name, systemImage: "folder")
                  if let areaName = project.area?.name {
                    Text(areaName)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
          }
        }

        if !areaResults.isEmpty {
          Section(L10n.string("search.section.areas")) {
            ForEach(areaResults) { area in
              NavigationLink {
                AreaDetailView(area: area)
              } label: {
                Label(area.name, systemImage: "square.grid.2x2")
              }
            }
          }
        }

        if !tagResults.isEmpty {
          Section(L10n.string("search.section.tags")) {
            ForEach(tagResults) { tag in
              NavigationLink {
                TagDetailView(tag: tag)
              } label: {
                Label(tag.name, systemImage: "tag")
              }
            }
          }
        }

        Section(L10n.string("search.section.tasks")) {
          if results.isEmpty {
            Text(L10n.string("search.no_matching_tasks"))
              .foregroundStyle(.secondary)
          } else {
            ForEach(results) { task in
              TaskRowView(
                task: task,
                onToggleDone: {
                  TaskCompletionEngine.complete(task, in: modelContext)
                },
                onOpen: {
                  TaskEditorCoordinator.shared.present(task: task)
                }
              )
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                  TaskCompletionEngine.complete(task, in: modelContext)
                } label: {
                  Label("Done", systemImage: "checkmark")
                }
                .tint(.green)
              }
            }
          }
        }
      }
    }
    .navigationTitle(L10n.string("nav.search"))
    .searchable(text: $query, prompt: L10n.string("search.prompt"))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Toggle(L10n.string("search.filter.include_attachments"), isOn: $includeAttachments)
          Toggle(L10n.string("search.filter.include_completed"), isOn: $includeCompleted)
          Toggle(L10n.string("search.filter.include_private"), isOn: $includePrivate)
        } label: {
          Image(systemName: "line.3.horizontal.decrease.circle")
        }
      }
    }
    .orbitBannerPlacement()
  }
}
