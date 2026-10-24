import SwiftUI

struct ArsenalView: View {
    let onBack: () -> Void
    @ObservedObject private var progress = ProgressionManager.shared

    var body: some View {
        ZStack {
            ArmoryBackdrop()
            VStack(spacing: 14) {
                ScreenHeader(title: "Arsenal", onBack: onBack) {
                    FragmentBadge(amount: progress.fragments)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(WeaponCatalog.all) { w in
                            WeaponCard(def: w, unlocked: progress.isUnlocked(w.id), loadout: progress.loadout)
                        }
                        LockedSlotCard()
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

private struct WeaponCard: View {
    let def: WeaponDefinition
    let unlocked: Bool
    let loadout: PlayerLoadout

    private var damage: Int { def.id == .pulseBlaster ? loadout.blasterDamage : def.baseDamage }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: unlocked ? def.symbol : "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(unlocked ? Theme.cyan : Theme.textSecondary)
                    .shadow(color: unlocked ? Theme.cyan.opacity(0.6) : .clear, radius: 8)
                Spacer()
                Text(unlocked ? "UNLOCKED" : "LOCKED")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(unlocked ? Theme.void : Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(unlocked ? Theme.cyan : Theme.midnight))
            }
            Text(def.name.uppercased())
                .trackedHeading(15, tracking: 2)
            Text(def.role)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.softViolet)
            Text(def.description)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(4)
                .frame(height: 64, alignment: .top)
            VStack(spacing: 6) {
                StatBar(label: "Damage", value: "\(damage)", fraction: Double(damage) / 40)
                StatBar(label: "Fire rate", value: String(format: "%.1f/s", def.attacksPerSecond), fraction: def.attacksPerSecond / 5.5)
                StatBar(label: "Range", value: "\(Int(def.range))", fraction: Double(def.range) / 600)
            }
            HStack(spacing: 6) {
                Image(systemName: def.armorPiercing ? "shield.slash" : "shield")
                    .font(.system(size: 11))
                Text(def.armorPiercing ? "Pierces armor" : "Weak vs armor")
                    .font(.system(size: 11))
            }
            .foregroundStyle(def.armorPiercing ? Theme.cyan : Theme.textSecondary)
            if !unlocked {
                Text(def.unlockHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(width: 260)
        .vlizPanel(highlighted: unlocked, cut: 14)
        .opacity(unlocked ? 1 : 0.75)
    }
}

private struct StatBar: View {
    let label: String
    let value: String
    let fraction: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.void.opacity(0.7))
                    Rectangle().fill(Theme.cyan).frame(width: g.size.width * min(1, max(0.05, fraction)))
                }
            }
            .frame(height: 5)
            .clipShape(Capsule())
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

private struct LockedSlotCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.diamond")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.softViolet)
            Text("UNKNOWN RELIC")
                .trackedHeading(13, tracking: 2, color: Theme.textSecondary)
            Text("Something else is buried beneath Vliz.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Text("COMING LATER")
                .trackedHeading(10, tracking: 3, color: Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(Theme.textSecondary.opacity(0.4)))
        }
        .padding(16)
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(ChamferShape(cut: 14).fill(Theme.void.opacity(0.4)))
        .overlay(ChamferShape(cut: 14).stroke(Theme.textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }
}
