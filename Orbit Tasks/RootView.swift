import SwiftUI

struct RootView: View {
    @StateObject private var undoCenter = OrbitUndoCenter()
    @StateObject private var experience = OrbitExperience.shared
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            NavigationStack { InboxView() }
                .tabItem { Label(L10n.string("tab.inbox"), systemImage: "tray.full") }

            NavigationStack { TodayView() }
                .tabItem { Label(L10n.string("tab.today"), systemImage: "sun.max") }

            NavigationStack { PlanView() }
                .tabItem { Label(L10n.string("tab.plan"), systemImage: "calendar") }

            NavigationStack { ReviewFlowView() }
                .tabItem { Label(L10n.string("tab.review"), systemImage: "checkmark.seal") }

            NavigationStack { BrowseView() }
                .tabItem { Label(L10n.string("tab.browse"), systemImage: "square.grid.2x2") }

            NavigationStack { SearchView() }
                .tabItem { Label(L10n.string("tab.search"), systemImage: "magnifyingglass") }

            NavigationStack { SettingsView() }
                .tabItem { Label(L10n.string("tab.settings"), systemImage: "gearshape") }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(settings.preferredColorScheme ?? .dark, for: .tabBar)
        .environmentObject(undoCenter)
        .orbitUndoToast(center: undoCenter)
        .overlay(TaskEditorCoordinator.shared.sheetPresenter())
        .fullScreenCover(isPresented: onboardingBinding) {
            OrbitOnboardingView {
                experience.completeOnboarding()
            }
        }
        .task {
            await OrbitAds.startMonetizationAfterLaunchIfNeeded()
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { experience.shouldShowOnboarding },
            set: { presented in
                if presented == false, experience.shouldShowOnboarding {
                    experience.completeOnboarding()
                }
            }
        )
    }
}
