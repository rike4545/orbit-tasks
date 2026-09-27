//
//  AreaEditorSheet.swift
//  Orbit Tasks
//  Area / Project / Tag editors
//  Swift 6 • iOS 17+

import SwiftData
import SwiftUI

// MARK: - Area Editor

struct AreaEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var name: String = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Area") {
          TextField("Area name", text: $name)
            .textInputAutocapitalization(.words)
        }
      }
      .navigationTitle("New Area")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { save() }
            .disabled(nameTrimmed.isEmpty)
        }
      }
    }
  }

  private var nameTrimmed: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func save() {
    let n = nameTrimmed
    guard !n.isEmpty else { return }

    let area = OrbitArea(name: n)
    modelContext.insert(area)
    try? modelContext.save()
    dismiss()
  }
}

// MARK: - Project Editor

struct ProjectEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @Query(sort: [SortDescriptor(\OrbitArea.name, order: .forward)])
  private var areas: [OrbitArea]

  let presetArea: OrbitArea?
  let project: OrbitProject?

  @State private var name: String = ""
  @State private var notes: String = ""
  @State private var deadlineAt: Date? = nil
  @State private var selectedAreaID: UUID? = nil

  init(presetArea: OrbitArea? = nil, project: OrbitProject? = nil) {
    self.presetArea = presetArea
    self.project = project
    _selectedAreaID = State(initialValue: presetArea?.id)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Project") {
          TextField("Project name", text: $name)
            .textInputAutocapitalization(.words)

          TextField("Notes (optional)", text: $notes, axis: .vertical)
            .lineLimit(2...6)

          DateFieldRow(label: "Deadline", date: $deadlineAt, systemImage: "flag")
        }

        if !areas.isEmpty {
          Section("Area") {
            Picker("Area", selection: $selectedAreaID) {
              Text("None").tag(UUID?.none)
              ForEach(areas) { a in
                Text(a.name).tag(UUID?.some(a.id))
              }
            }
          }
        }
      }
      .navigationTitle(project == nil ? "New Project" : "Edit Project")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { save() }
            .disabled(nameTrimmed.isEmpty)
        }
      }
      .onAppear {
        if let project, name.isEmpty {
          name = project.name
          notes = project.notes
          deadlineAt = project.deadlineAt
          selectedAreaID = project.area?.id
        } else if selectedAreaID == nil {
          selectedAreaID = presetArea?.id
        }
      }
    }
  }

  private var nameTrimmed: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var notesTrimmed: String {
    notes.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func save() {
    let n = nameTrimmed
    guard !n.isEmpty else { return }

    let area = areas.first(where: { $0.id == selectedAreaID })

    if let project {
      project.name = n
      project.notes = notesTrimmed
      project.deadlineAt = deadlineAt
      project.area = area
    } else {
      let project = OrbitProject(
        name: n,
        notes: notesTrimmed,
        deadlineAt: deadlineAt,
        area: area
      )
      modelContext.insert(project)
    }

    try? modelContext.save()
    dismiss()
  }
}

// MARK: - Tag Editor

struct TagEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var name: String = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Tag") {
          TextField("Tag name", text: $name)
            .textInputAutocapitalitalizationCompatWords()
        }
      }
      .navigationTitle("New Tag")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { save() }
            .disabled(nameTrimmed.isEmpty)
        }
      }
    }
  }

  private var nameTrimmed: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func save() {
    let n = nameTrimmed
    guard !n.isEmpty else { return }

    let tag = OrbitTag(name: n)
    modelContext.insert(tag)
    try? modelContext.save()
    dismiss()
  }
}

// MARK: - Tiny compatibility helper (avoids iOS 17 quirks in some projects)

extension View {
  fileprivate func textInputAutocapitalitalizationCompatWords() -> some View {
    self.textInputAutocapitalization(.words)
  }
}
