//
//  OrbitAppStyle.swift
//  Orbit Tasks
import SwiftUI
import UIKit

struct OrbitAppStyle: ViewModifier {
    @ObservedObject var settings: AppSettings

    func body(content: Content) -> some View {
        ZStack {
            if settings.themedBackground {
                settings.backgroundGradient
                    .ignoresSafeArea()
            }

            content
        }
        .tint(settings.accentColor)
        .fontDesign(.rounded)
        .preferredColorScheme(settings.preferredColorScheme)
        .dynamicTypeSize(settings.dynamicTypeSize)
        .onAppear {
            applyListAppearance()
            applyNavigationAndTabAppearance()
        }
        .onChange(of: settings.themedBackground) { _, _ in
            applyListAppearance()
        }
        .onChange(of: settings.customAccentHex) { _, _ in
            applyNavigationAndTabAppearance()
        }
        .onChange(of: settings.palette) { _, _ in
            applyNavigationAndTabAppearance()
        }
        .onChange(of: settings.useCustomAccent) { _, _ in
            applyNavigationAndTabAppearance()
        }
    }

    private func applyListAppearance() {
        // Make Lists transparent so your gradient shows through (optional via setting).
        if settings.themedBackground {
            UITableView.appearance().backgroundColor = .clear
            UITableViewCell.appearance().backgroundColor = .clear
        } else {
            UITableView.appearance().backgroundColor = nil
            UITableViewCell.appearance().backgroundColor = nil
        }
    }

    private func applyNavigationAndTabAppearance() {
        let tint = UIColor(settings.accentColor)
        UITabBar.appearance().tintColor = tint
        UINavigationBar.appearance().tintColor = tint
    }
}

extension View {
    func orbitAppStyle(_ settings: AppSettings) -> some View {
        modifier(OrbitAppStyle(settings: settings))
    }
}
