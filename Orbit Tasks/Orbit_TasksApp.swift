//
//  Orbit_TasksApp.swift
//  Orbit Tasks
//
//  Swift 6 • iOS 17+ • SwiftData
//

import GoogleMobileAds
import SwiftData
import SwiftUI

@main
struct Orbit_TasksApp: App {
  @StateObject private var settings = AppSettings()
  @StateObject private var purchases = OrbitPurchaseManager()
  @StateObject private var experience = OrbitExperience.shared
  @Environment(\.scenePhase) private var scenePhase

  private let container: ModelContainer = OrbitModelContainer.make()

  init() {
    OrbitAds.configureSDKForLaunch()
    OrbitExperience.shared.beginSession()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(settings)
        .environmentObject(purchases)
        .environmentObject(experience)
        .orbitAppStyle(settings)
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
          switch newPhase {
          case .active:
            OrbitAppOpenAdManager.shared.sceneDidBecomeActive()
          case .background:
            OrbitAppOpenAdManager.shared.sceneDidEnterBackground()
          default:
            break
          }
        }
    }
  }
}

// MARK: - Container factory with recovery

enum OrbitModelContainer {

  static func make() -> ModelContainer {
    let schema = Schema([
      OrbitArea.self,
      OrbitProject.self,
      OrbitTag.self,
      OrbitTask.self,
      OrbitAttachment.self,
      OrbitChecklistItem.self,
    ])

    let storeURL = persistentStoreURL(filename: "OrbitTasks.store")

    let config = ModelConfiguration(
      "OrbitTasks",
      schema: schema,
      url: storeURL,
      allowsSave: true,
      cloudKitDatabase: .none
    )

    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      destroyStoreFiles(at: storeURL)

      do {
        return try ModelContainer(for: schema, configurations: [config])
      } catch {
        let mem = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
          return try ModelContainer(for: schema, configurations: [mem])
        } catch {
          fatalError("Failed to create ModelContainer: \(error)")
        }
      }
    }
  }

  private static func persistentStoreURL(filename: String) -> URL {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    try? FileManager.default.createDirectory(
      at: base, withIntermediateDirectories: true, attributes: nil)
    return base.appendingPathComponent(filename)
  }

  private static func destroyStoreFiles(at storeURL: URL) {
    let fm = FileManager.default

    let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
    let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")

    try? fm.removeItem(at: storeURL)
    try? fm.removeItem(at: walURL)
    try? fm.removeItem(at: shmURL)
  }
}
