import SwiftUI
import Domain
import Infrastructure

/// Claude provider configuration card for SettingsView.
struct ClaudeConfigCard: View {
    let monitor: QuotaMonitor

    @State private var settings = AppSettings.shared
    @Environment(\.appTheme) private var theme

    @State private var claudeConfigExpanded: Bool = false
    @State private var claudeBudgetExpanded: Bool = false
    @State private var claudeProbeMode: ClaudeProbeMode = .cli
    @State private var claudeCliFallbackEnabled: Bool = true
    @State private var budgetInput: String = ""

    var body: some View {
        VStack(spacing: 12) {
            configCard
            budgetCard
        }
        .onAppear {
            claudeProbeMode = settings.claude.claudeProbeMode()
            claudeCliFallbackEnabled = settings.claude.claudeCliFallbackEnabled()
            if settings.claudeApiBudget > 0 {
                budgetInput = String(describing: settings.claudeApiBudget)
            }
        }
    }

    // MARK: - Config Card

    private var configCard: some View {
        DisclosureGroup(isExpanded: $claudeConfigExpanded) {
            Divider()
                .background(theme.glassBorder)
                .padding(.vertical, 12)

            configForm
        } label: {
            configHeader
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        claudeConfigExpanded.toggle()
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
    }

    private var configHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.55, blue: 0.35),
                                Color(red: 0.75, green: 0.40, blue: 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "gear")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Claude 配置")
                    .font(.system(size: 14, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("数据获取方式")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()
        }
    }

    private var configForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("探测模式")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)

                Picker("", selection: $claudeProbeMode) {
                    ForEach(ClaudeProbeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: claudeProbeMode) { _, newValue in
                    settings.claude.setClaudeProbeMode(newValue)
                    Task {
                        await monitor.refresh(providerId: "claude")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundStyle(claudeProbeMode == .cli ? theme.accentPrimary : theme.textTertiary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CLI Mode")
                            .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(claudeProbeMode == .cli ? theme.textPrimary : theme.textSecondary)

                        Text("运行 `claude /usage` 命令。支持任何认证方式。")
                            .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                        .foregroundStyle(claudeProbeMode == .api ? theme.accentPrimary : theme.textTertiary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("API Mode")
                            .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(claudeProbeMode == .api ? theme.textPrimary : theme.textSecondary)

                        Text("直接调用 Anthropic API。更快，使用 OAuth 凭据。")
                            .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            if claudeProbeMode == .api {
                let credentialLoader = ClaudeCredentialLoader()
                let hasCredentials = credentialLoader.loadCredentials() != nil

                HStack(spacing: 6) {
                    Image(systemName: hasCredentials ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(hasCredentials ? theme.statusHealthy : theme.statusWarning)

                    Text(hasCredentials ? "已找到 OAuth 凭据" : "未找到 OAuth 凭据")
                        .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(hasCredentials ? theme.statusHealthy : theme.statusWarning)
                }

                if !hasCredentials {
                    Text("在终端运行 `claude` 进行认证，之后凭据即可使用。")
                        .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                Toggle(isOn: $claudeCliFallbackEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CLI 回退")
                            .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("当 OAuth API 不可用时回退到 `claude /usage`。")
                            .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .tint(theme.accentPrimary)
                .onChange(of: claudeCliFallbackEnabled) { _, newValue in
                    settings.claude.setClaudeCliFallbackEnabled(newValue)
                }
            }
        }
    }

    // MARK: - Budget Card

    private var budgetCard: some View {
        DisclosureGroup(isExpanded: $claudeBudgetExpanded) {
            Divider()
                .background(theme.glassBorder)
                .padding(.vertical, 12)

            budgetForm
                .disabled(!settings.claudeApiBudgetEnabled)
                .opacity(settings.claudeApiBudgetEnabled ? 1 : 0.6)
        } label: {
            budgetHeader
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        claudeBudgetExpanded.toggle()
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
    }

    private var budgetHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.55, blue: 0.35),
                                Color(red: 0.75, green: 0.40, blue: 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Claude API 预算")
                    .font(.system(size: 14, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("费用阈值预警")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $settings.claudeApiBudgetEnabled)
                .toggleStyle(.switch)
                .tint(theme.accentPrimary)
                .scaleEffect(0.8)
                .labelsHidden()
        }
    }

    private var budgetForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("每月预算 (USD)")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)

                HStack(spacing: 6) {
                    Text("$")
                        .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)

                    TextField("", text: $budgetInput, prompt: Text("10.00").foregroundStyle(theme.textTertiary))
                        .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.glassBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.glassBorder, lineWidth: 1)
                                )
                        )
                        .onChange(of: budgetInput) { _, newValue in
                            if let value = Decimal(string: newValue) {
                                settings.claudeApiBudget = value
                            }
                        }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("接近预算阈值时发出预警。")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Text("仅适用于 Claude API 账号，不适用于 Claude Max。")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }
}
