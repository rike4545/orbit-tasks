//
//  AttachmentLibraryView.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/17/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AttachmentLibraryView: View {
  @Query(sort: [SortDescriptor(\OrbitAttachment.createdAt, order: .reverse)])
  private var attachments: [OrbitAttachment]

  @State private var query: String = ""
  @State private var includePrivate: Bool = false

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var filtered: [OrbitAttachment] {
    let q = trimmedQuery
    if q.isEmpty, includePrivate { return attachments }

    return attachments.filter { att in
      if !includePrivate, att.task?.isPrivate == true { return false }
      guard !q.isEmpty else { return true }

      if att.displayName.localizedCaseInsensitiveContains(q) { return true }
      if att.uti.localizedCaseInsensitiveContains(q) { return true }
      if let t = att.indexedText, t.localizedCaseInsensitiveContains(q) { return true }
      if let title = att.task?.title, title.localizedCaseInsensitiveContains(q) { return true }
      return false
    }
  }

  var body: some View {
    List {
      if filtered.isEmpty {
        EmptyStateView(
          systemImage: "paperclip",
          title: "Library",
          subtitle: "No matching attachments."
        )
        .listRowSeparator(.hidden)
      } else {
        Section {
          ForEach(filtered) { att in
            AttachmentLibraryRow(
              attachment: att,
              iconName: icon(for: att),
              onOpenTask: {
                if let task = att.task {
                  TaskEditorCoordinator.shared.present(task: task)
                }
              },
              onReindex: {
                Task { await AttachmentTextIndexer.indexIfNeeded(att, force: true) }
              }
            )
          }
        } header: {
          Text("Attachments (\(filtered.count))")
        }
      }
    }
    .navigationTitle("Library")
    .searchable(text: $query, prompt: "Filename, OCR text, task title…")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Toggle("Include Private", isOn: $includePrivate)

          Button("Index Missing Text") {
            let toIndex = filtered.filter { $0.indexedText == nil }
            guard !toIndex.isEmpty else { return }

            Task {
              for att in toIndex {
                await AttachmentTextIndexer.indexIfNeeded(att)
              }
            }
          }
        } label: {
          Image(systemName: "line.3.horizontal.decrease.circle")
        }
      }
    }
  }

  private func icon(for att: OrbitAttachment) -> String {
    let type = UTType(att.uti)
    if type?.conforms(to: .pdf) == true { return "doc.richtext" }
    if type?.conforms(to: .image) == true { return "photo" }
    if type?.conforms(to: .plainText) == true { return "doc.plaintext" }
    if type?.conforms(to: .text) == true { return "doc.text" }
    return "paperclip"
  }
}

private struct AttachmentLibraryRow: View {
  let attachment: OrbitAttachment
  let iconName: String
  let onOpenTask: () -> Void
  let onReindex: () -> Void

  private var isIndexed: Bool {
    guard let t = attachment.indexedText else { return false }
    return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var taskSubtitle: String? {
    guard let task = attachment.task else { return nil }
    return task.isPrivate ? "Private task" : task.title
  }

  private var indexedSubtitle: String? {
    guard let ts = attachment.indexedAt else { return nil }
    return "Indexed \(formatted(ts))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        Image(systemName: iconName)
          .foregroundStyle(.secondary)

        Text(attachment.displayName)
          .font(.headline)
          .lineLimit(1)

        Spacer()

        if isIndexed {
          Image(systemName: "text.magnifyingglass")
            .foregroundStyle(.secondary)
        }
      }

      if let subtitle = taskSubtitle {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let subtitle = indexedSubtitle {
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .contentShape(Rectangle())
    .overlay {
      Button(action: onOpenTask) {
        Color.clear
      }
      .buttonStyle(.plain)
    }
    .swipeActions(edge: .trailing) {
      Button(action: onReindex) {
        Label(isIndexed ? "Reindex" : "Index", systemImage: "text.viewfinder")
      }
      .tint(.blue)
    }
  }

  private func formatted(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
    return df.string(from: date)
  }
}
