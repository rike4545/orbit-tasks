//
//  AutoPlanSheet.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/17/26.
//


import SwiftUI
import SwiftData

struct AutoPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let todayTasks: [OrbitTask]

    @State private var cfg = AutoPlanner.Config()

    var body: some View {
        NavigationStack {
            Form {
                Section("Day window") {
                    Stepper("Start hour: \(cfg.startHour):00", value: $cfg.startHour, in: 0...23)
                    Stepper("End hour: \(cfg.endHour):00", value: $cfg.endHour, in: 0...23)
                }

                Section("Breaks") {
                    Stepper("Break every \(cfg.breakMinutesEvery) min", value: $cfg.breakMinutesEvery, in: 0...240, step: 15)
                    if cfg.breakMinutesEvery > 0 {
                        Stepper("Break duration \(cfg.breakMinutes) min", value: $cfg.breakMinutes, in: 0...60, step: 5)
                    }
                }

                Section("Defaults") {
                    Stepper("Default task \(cfg.defaultTaskMinutes) min", value: $cfg.defaultTaskMinutes, in: 5...120, step: 5)
                }

                Section {
                    Button {
                        AutoPlanner.applyPlanForToday(tasks: todayTasks, config: cfg, modelContext: modelContext)
                        dismiss()
                    } label: {
                        Label("Apply Auto-Plan to Today", systemImage: "wand.and.stars")
                    }
                }
            }
            .navigationTitle("Auto-Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
