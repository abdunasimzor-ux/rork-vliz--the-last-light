import SwiftUI

struct MissionCompleteView: View {
    let result: MissionResult
    let onContinue: () -> Void
    let onReplay: () -> Void

    @ObservedObject private var progress = ProgressionManager.shared
    @State private var stage = 0
    @State private var countedFragments = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("cyan_energy_core_shaft")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(stage > 0 ? 1.04 : 1.12)
                    .clipped()
                    .ignoresSafeArea()
                LinearGradient(colors: [.clear, Theme.void.opacity(0.75), Theme.void.opacity(0.95)],
                               startPoint: .leading, endPoint: .trailing)
                    .ignoresSafeArea()
                MotesView(color: Theme.cyan, count: 30, intensity: 0.8).ignoresSafeArea()

                HStack(alignment: .center, spacing: 24) {
                    // Title block
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()
                        Text("MISSION \(result.missionCode) · \(result.missionTitle.uppercased())")
                            .trackedHeading(11, tracking: 3, color: Theme.textSecondary)
                        Text("COMPLETE")
                            .font(.system(size: 40, weight: .heavy))
                            .tracking(12)
                            .foregroundStyle(Theme.textPrimary)
                            .shadow(color: Theme.cyan.opacity(0.8), radius: 16)
                            .opacity(stage > 0 ? 1 : 0)
                            .scaleEffect(stage > 0 ? 1 : 1.2, anchor: .leading)
                        GlowRule().frame(width: 300)
                        Text("“…Kael. We have been waiting.”")
                            .font(.system(size: 13).italic())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 6)
                            .opacity(stage > 2 ? 1 : 0)
                        Spacer().frame(height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Stats panel
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(spacing: 0) {
                                StatRow(symbol: "scope", label: "Enemies defeated", value: "\(result.enemiesDefeated)")
                                Divider().overlay(Theme.textSecondary.opacity(0.2))
                                StatRow(symbol: "diamond.fill", label: "Energy shards", value: "\(result.shardsCollected) / \(result.shardsTotal)")
                                Divider().overlay(Theme.textSecondary.opacity(0.2))
                                StatRow(symbol: "diamond.fill", label: "Fragments earned", value: "\(countedFragments)")
                                Divider().overlay(Theme.textSecondary.opacity(0.2))
                                StatRow(symbol: "shield.lefthalf.filled", label: "Commander Rhex",
                                        value: result.bossDefeated ? "Defeated" : "—", highlight: true)
                            }
                            .padding(.horizontal, 14)
                            .vlizPanel(cut: 10)
                            .opacity(stage > 1 ? 1 : 0)
                            .offset(y: stage > 1 ? 0 : 10)

                            Text("REWARDS")
                                .trackedHeading(10, tracking: 3, color: Theme.textSecondary)
                            VStack(spacing: 0) {
                                if let w = result.unlockedWeapon {
                                    StatRow(symbol: "bolt.horizontal.fill", label: "+ \(WeaponCatalog.definition(w).name) unlocked", value: "")
                                    Divider().overlay(Theme.textSecondary.opacity(0.2))
                                }
                                StatRow(symbol: "diamond.fill",
                                        label: "+ \(result.bonusFragments) \(result.firstClear ? "first clear bonus" : "replay bonus")", value: "")
                                Divider().overlay(Theme.textSecondary.opacity(0.2))
                                StatRow(symbol: "wallet.bifold.fill", label: "Wallet", value: progress.fragments.formatted())
                            }
                            .padding(.horizontal, 14)
                            .vlizPanel(cut: 10)
                            .opacity(stage > 2 ? 1 : 0)
                            .offset(y: stage > 2 ? 0 : 10)

                            HStack(spacing: 10) {
                                Button {
                                    Haptics.tap()
                                    AudioManager.shared.play(.uiTap)
                                    onReplay()
                                } label: {
                                    Text("REPLAY").trackedHeading(13, tracking: 3)
                                        .frame(maxWidth: .infinity).frame(height: 46)
                                        .background(Capsule().fill(Theme.midnight.opacity(0.75)))
                                        .overlay(Capsule().stroke(Theme.textSecondary.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(VlizPressStyle())
                                Button {
                                    Haptics.medium()
                                    AudioManager.shared.play(.uiTap)
                                    onContinue()
                                } label: {
                                    Text("CONTINUE").trackedHeading(13, tracking: 3)
                                        .frame(maxWidth: .infinity).frame(height: 46)
                                        .background(Capsule().fill(Theme.teal.opacity(0.8)))
                                        .overlay(Capsule().stroke(Theme.cyan, lineWidth: 1.4))
                                        .shadow(color: Theme.cyan.opacity(0.45), radius: 10)
                                }
                                .buttonStyle(VlizPressStyle())
                            }
                            .padding(.top, 4)
                            .opacity(stage > 2 ? 1 : 0)
                        }
                        .padding(.vertical, 20)
                    }
                    .frame(width: min(380, geo.size.width * 0.46))
                }
                .padding(.horizontal, 32)
            }
        }
        .background(Theme.void)
        .task {
            AudioManager.shared.playMusic(.menu, fade: 1.5)
            withAnimation(.easeOut(duration: 1.6)) { stage = 1 }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.5)) { stage = 2 }
            await countUp()
            withAnimation(.easeOut(duration: 0.5)) { stage = 3 }
            Haptics.success()
        }
    }

    private func countUp() async {
        let target = result.fragmentsEarned
        guard target > 0 else { return }
        let steps = min(30, target)
        for i in 1...steps {
            try? await Task.sleep(for: .milliseconds(30))
            countedFragments = target * i / steps
            if i % 3 == 0 { AudioManager.shared.play(.pickup, volume: 0.3) }
        }
    }
}

private struct StatRow: View {
    let symbol: String
    let label: String
    let value: String
    var highlight = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.cyan)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(highlight ? Theme.cyan : Theme.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(height: 40)
    }
}
