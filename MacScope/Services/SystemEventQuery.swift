import Foundation

enum SystemEventQuery {
    static func apply(
        to events: [SystemEvent],
        kind: SystemEvent.Kind?,
        severity: SystemEventSeverityFilter,
        searchText: String
    ) -> [SystemEvent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return events.reversed().filter { event in
            (kind == nil || event.kind == kind)
                && severity.includes(event.severity)
                && (query.isEmpty
                    || event.title.localizedCaseInsensitiveContains(query)
                    || event.message.localizedCaseInsensitiveContains(query)
                    || event.kind.title.localizedCaseInsensitiveContains(query))
        }
    }
}
