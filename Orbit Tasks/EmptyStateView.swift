//
//  EmptyStateView.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/16/26.
//


//  EmptyStateView.swift
//  OrbitTasks
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(12)
                .background(Color.white.opacity(0.08), in: Circle())

            Text(title)
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 16)
        .orbitCardStyle()
    }
}
