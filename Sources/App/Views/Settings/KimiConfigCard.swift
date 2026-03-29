import SwiftUI
import Domain
import Infrastructure

/// Kimi provider configuration card for SettingsView.
struct KimiConfigCard: View {
    let monitor: QuotaMonitor

    @State private var settings = AppSettings.shared
    @Environment(\.appTheme) private var theme

    @State private var kimiConfigExpanded: Bool = false
    @State private var kimiProbeMode: KimiProbeMode = .cli

    var body: some View {
        DisclosureGroup(isExpanded: $kimiConfigExpanded) {
            Divider()
                .background(theme.glassBorder)
                .padding(.vertical, 12)

            kimiConfigForm
        } label: {
            kimiConfigHeader
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        kimiConfigExpanded.toggle()
                    }
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.glassBorder, theme.glassBorder.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            kimiProbeMode = settings.kimi.kimiProbeMode()
        }
    }

    private var kimiConfigHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accentPrimary.opacity(0.2), theme.accentSecondary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Kimi 配置")
                    .font(.system(size: 14, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("数据获取方式")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()
        }
    }

    private var kimiConfigForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("探测模式")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)

                Picker("", selection: $kimiProbeMode) {
                    ForEach(KimiProbeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: kimiProbeMode) { _, newValue in
                    settings.kimi.setKimiProbeMode(newValue)
                    Task {
                        await monitor.refresh(providerId: "kimi")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundStyle(kimiProbeMode == .cli ? theme.accentPrimary : theme.textTertiary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CLI Mode")
                            .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(kimiProbeMode == .cli ? theme.textPrimary : theme.textSecondary)

                        Text("使用 kimi CLI 的 /usage 命令。需要安装 kimi。")
                            .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                        .foregroundStyle(kimiProbeMode == .api ? theme.accentPrimary : theme.textTertiary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("API Mode")
                            .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(kimiProbeMode == .api ? theme.textPrimary : theme.textSecondary)

                        Text("直接调用 Kimi API。使用浏览器 Cookie 认证。")
                            .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
        }
    }
}
