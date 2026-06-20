//
//  TaskSelectionBar.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/17/26.
//


import SwiftUI

struct TaskSelectionBar: View {
    let count: Int

    let onComplete: () -> Void
    let onScheduleToday: () -> Void
    let onMoveToEvening: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label("\(count) \(L10n.string("selection.selected"))", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onComplete()
            } label: {
                Label(L10n.string("selection.done"), systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)

            Menu {
                Button {
                    onScheduleToday()
                } label: {
                    Label(L10n.string("selection.schedule_today"), systemImage: "sun.max")
                }

                Button {
                    onMoveToEvening()
                } label: {
                    Label(L10n.string("selection.move_evening"), systemImage: "moon.stars")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(L10n.string("common.delete"), systemImage: "trash")
                }

            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
        }
        .orbitBarStyle()
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}
