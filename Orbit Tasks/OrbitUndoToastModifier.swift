//
//  OrbitUndoToastModifier.swift
//  Orbit Tasks
//  Adds `.orbitUndoToast()` to any view.

import SwiftUI

// MARK: - Public API

extension View {

  /// Uses the `OrbitUndoCenter` from the environment.
  func orbitUndoToast() -> some View {
    modifier(OrbitUndoToastEnvironmentModifier())
  }

  /// Uses an explicit center (handy for RootView).
  func orbitUndoToast(center: OrbitUndoCenter) -> some View {
    modifier(OrbitUndoToastModifier(center: center))
  }
}

// MARK: - Modifier (explicit center)

private struct OrbitUndoToastModifier: ViewModifier {
  @ObservedObject var center: OrbitUndoCenter

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if let toast = center.toast {
          OrbitUndoToastView(
            message: toast.message,
            actionTitle: toast.actionTitle,
            onUndo: { center.performUndo() },
            onDismiss: { center.dismiss() }
          )
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .padding(.bottom, 12)
          .padding(.horizontal, 12)
          .zIndex(999)
        }
      }
      .animation(.spring(response: 0.35, dampingFraction: 0.9), value: center.toast?.id)
  }
}

// MARK: - Modifier (environment center)

private struct OrbitUndoToastEnvironmentModifier: ViewModifier {
  @EnvironmentObject private var center: OrbitUndoCenter

  func body(content: Content) -> some View {
    content.modifier(OrbitUndoToastModifier(center: center))
  }
}

// MARK: - Toast View

private struct OrbitUndoToastView: View {
  let message: String
  let actionTitle: String
  let onUndo: () -> Void
  let onDismiss: () -> Void

  @State private var isPressing = false

  var body: some View {
    HStack(spacing: 12) {
      Text(message)
        .font(.subheadline)
        .lineLimit(2)
        .foregroundStyle(.primary)

      Spacer(minLength: 0)

      Button(actionTitle) {
        onUndo()
      }
      .font(.subheadline.weight(.semibold))
      .buttonStyle(.borderedProminent)

      Button {
        onDismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.subheadline.weight(.semibold))
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
      .accessibilityLabel("Dismiss")
    }
    .padding(12)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(.quaternary, lineWidth: 1)
    )
    .shadow(radius: 12, y: 6)
    .scaleEffect(isPressing ? 0.98 : 1.0)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressing = true }
        .onEnded { _ in isPressing = false }
    )
  }
}
