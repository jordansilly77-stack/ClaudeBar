import Domain

public extension QuotaMonitor {
    convenience init(
        providers: any AIProviderRepository,
        alerter: (any QuotaAlerter)? = nil,
        dailyUsageAnalyzer: (any DailyUsageAnalyzing)? = nil
    ) {
        self.init(providers: providers, alerter: alerter, clock: SystemClock(), dailyUsageAnalyzer: dailyUsageAnalyzer)
    }
}
