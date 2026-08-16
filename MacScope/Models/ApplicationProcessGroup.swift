struct ApplicationProcessGroup: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let applicationPath: String?
    let processes: [ProcessSnapshot]
    let residentBytes: UInt64
    let cpuPercent: Double
    let threadCount: Int
}
