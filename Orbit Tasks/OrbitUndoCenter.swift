//
//  OrbitUndoCenter.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/19/26.
//


//
//  OrbitUndoCenter.swift
//  Orbit Tasks
//
//  Simple undo toast state + action dispatcher
//

import Foundation
import Combine

@MainActor
final class OrbitUndoCenter: ObservableObject {

    struct Toast: Identifiable, Equatable {
        let id: UUID
        let message: String
        let actionTitle: String
        let createdAt: Date
        let duration: TimeInterval

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    @Published private(set) var toast: Toast? = nil

    private var undoHandler: (() -> Void)?
    private var dismissTask: Task<Void, Never>?

    /// Show a toast with an Undo action.
    func showUndo(
        message: String,
        actionTitle: String = "Undo",
        duration: TimeInterval = 5,
        undo: @escaping () -> Void
    ) {
        dismissTask?.cancel()
        dismissTask = nil

        let newToast = Toast(
            id: UUID(),
            message: message,
            actionTitle: actionTitle,
            createdAt: Date(),
            duration: duration
        )

        toast = newToast
        undoHandler = undo

        dismissTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(max(0.5, duration)))
            if !Task.isCancelled {
                await MainActor.run { self.dismiss() }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        toast = nil
        undoHandler = nil
    }

    func performUndo() {
        let handler = undoHandler
        dismiss()
        handler?()
    }
}
