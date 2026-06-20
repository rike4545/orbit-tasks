import SwiftUI

struct OrbitOnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color.indigo.opacity(0.55), Color.black.opacity(0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Welcome to Orbit")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Start fast, clear a few tasks, and get a feel for your flow before any ads appear.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                }

                VStack(spacing: 14) {
                    onboardingCard(
                        systemImage: "square.and.pencil",
                        title: "Capture quickly",
                        body: "Drop tasks into Inbox in seconds, then sort them later when you have more context."
                    )

                    onboardingCard(
                        systemImage: "sun.max",
                        title: "Plan today",
                        body: "Move the important work into Today so the app feels useful right away."
                    )

                    onboardingCard(
                        systemImage: "checkmark.circle",
                        title: "Build momentum",
                        body: "Completing a few tasks early helps Orbit adapt without interrupting your first session."
                    )
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Start Organizing")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
    }

    private func onboardingCard(systemImage: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
