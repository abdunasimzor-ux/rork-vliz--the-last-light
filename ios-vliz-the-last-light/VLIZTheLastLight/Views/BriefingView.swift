import SwiftUI

struct BriefingView: View {
    let onBack: () -> Void
    let onLaunch: () -> Void
    let onWatchIntro: () -> Void
    @ObservedObject private var progress = ProgressionManager.shared
    @State private var selectedChapter = 1

    private let mission = Campaign.mission001

    var body: some View {
        ZStack {
            MenuBackdrop(imageName: "burning_alien_skyline", time: AtmosphereManager.resolve(progress.settings.atmosphere))
            Theme.void.opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Campaign", onBack: onBack) {
                    FragmentBadge(amount: progress.fragments)
                }

                HStack(alignment: .top, spacing: 16) {
                    chapterRail
                        .frame(width: 220)
                    missionCard
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private var chapterRail: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(Campaign.chapters) { ch in
                    let playable = ch.id == 1
                    Button {
                        Haptics.tap()
                        AudioManager.shared.play(.uiTap)
                        selectedChapter = ch.id
                    } label: {
                        HStack(spacing: 12) {
                            Text(ch.numeral)
                                .font(.system(size: 15, weight: .bold).monospacedDigit())
                                .foregroundStyle(playable ? Theme.cyan : Theme.textSecondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ch.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(playable ? Theme.textPrimary : Theme.textSecondary)
                                    .lineLimit(1)
                                Text(playable ? "1 of \(ch.plannedMissions) missions playable" : "Coming later")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                            if !playable {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .vlizPanel(highlighted: selectedChapter == ch.id, cut: 8)
                    }
                    .buttonStyle(VlizPressStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var missionCard: some View {
        if selectedChapter == 1 {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CHAPTER I · MISSION \(mission.code)")
                            .trackedHeading(11, tracking: 3, color: Theme.cyan)
                        Spacer()
                        if progress.isCompleted(mission.id) {
                            Label("Cleared ×\(progress.record(for: mission.id)?.clears ?? 0)", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.cyan)
                        }
                    }
                    Text(mission.title.uppercased())
                        .font(.system(size: 26, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(Theme.textPrimary)
                    Text(mission.synopsis)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("OBJECTIVES")
                        .trackedHeading(10, tracking: 3, color: Theme.textSecondary)
                        .padding(.top, 2)
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                        ForEach(mission.objectives) { obj in
                            HStack(spacing: 8) {
                                Image(systemName: "diamond")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.cyan)
                                Text(obj.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            Haptics.medium()
                            AudioManager.shared.play(.uiTap)
                            onLaunch()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                Text("LAUNCH").tracking(3)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .vlizPanel(highlighted: true)
                        }
                        .buttonStyle(VlizPressStyle())

                        Button {
                            Haptics.tap()
                            AudioManager.shared.play(.uiTap)
                            onWatchIntro()
                        } label: {
                            Label("Watch intro", systemImage: "film")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .vlizPanel()
                        }
                        .buttonStyle(VlizPressStyle())
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .vlizPanel(cut: 14)
            }
        } else if let ch = Campaign.chapters.first(where: { $0.id == selectedChapter }) {
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.softViolet)
                Text("CHAPTER \(ch.numeral)")
                    .trackedHeading(11, tracking: 3, color: Theme.softViolet)
                Text(ch.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(ch.teaser)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text("COMING LATER")
                    .trackedHeading(11, tracking: 4, color: Theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Theme.textSecondary.opacity(0.4)))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .vlizPanel(cut: 14)
        }
    }
}
