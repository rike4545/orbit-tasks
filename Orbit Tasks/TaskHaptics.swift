import UIKit

enum TaskHaptics {
  private static var enabled: Bool {
    UserDefaults.standard.object(forKey: "orbit.hapticsEnabled") as? Bool ?? true
  }

  static func success() {
    guard enabled else { return }
    let gen = UINotificationFeedbackGenerator()
    gen.prepare()
    gen.notificationOccurred(.success)
  }

  static func light() {
    guard enabled else { return }
    let gen = UIImpactFeedbackGenerator(style: .light)
    gen.prepare()
    gen.impactOccurred()
  }

  static func medium() {
    guard enabled else { return }
    let gen = UIImpactFeedbackGenerator(style: .medium)
    gen.prepare()
    gen.impactOccurred()
  }
}
