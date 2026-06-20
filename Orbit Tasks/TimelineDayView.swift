//
//  TimelineDayView.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/17/26.
//


import SwiftUI

struct TimelineDayView: View {
    let day: Date
    let tasks: [OrbitTask]

    private let hourHeight: CGFloat = 64

    private var dayStart: Date { Calendar.current.startOfDay(for: day) }
    private var dayEnd: Date { Calendar.current.date(byAdding: .day, value: 1, to: dayStart)! }

    private struct PlacedTask: Identifiable {
        let id: UUID
        let task: OrbitTask
        let start: Date
        let minutes: Int
    }

    private var placed: [PlacedTask] {
        tasks.compactMap { t in
            // Choose a start:
            let start = t.blockStartAt
                ?? t.scheduledAt
                ?? nil

            guard let s = start else { return nil }
            guard s >= dayStart && s < dayEnd else { return nil }

            let mins = t.blockDurationMinutes
                ?? t.estimatedMinutes
                ?? 30

            return PlacedTask(id: t.id, task: t, start: s, minutes: max(10, mins))
        }
        .sorted { $0.start < $1.start }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    hourGrid

                    ForEach(placed) { p in
                        taskCard(p)
                            .offset(x: 72, y: yOffset(for: p.start))
                            .frame(width: max(proxy.size.width - 100, 160), alignment: .leading)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(DateHelpers.dayString(day))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 12) {
                    Text(DateHelpers.hourGridLabel(hour: hour, on: day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)

                    Rectangle()
                        .fill(.separator)
                        .frame(height: 1)

                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
        .padding(.horizontal, 12)
    }

    private func yOffset(for date: Date) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = CGFloat(comps.hour ?? 0)
        let m = CGFloat(comps.minute ?? 0)
        return (h * hourHeight) + (m / 60.0 * hourHeight)
    }

    private func taskCard(_ p: PlacedTask) -> some View {
        let height = max(36, CGFloat(p.minutes) / 60.0 * hourHeight)

        return VStack(alignment: .leading, spacing: 6) {
            Text(p.task.title)
                .font(.subheadline)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(DateHelpers.timeString(p.start))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(p.minutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if p.task.isEvening {
                    Text("Evening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(height: height, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
