enum MetricAvailability<Value: Sendable>: Sendable {
    case available(Value)
    case unavailable(reason: String)
    case unsupported(reason: String)
}

extension MetricAvailability: Equatable where Value: Equatable {}
