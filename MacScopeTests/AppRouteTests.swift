import Testing
@testable import MacScope

struct AppRouteTests {
    @Test func hiddenDetailRoutesResolveToVisibleParentsAndTypedTabs() {
        #expect(AppRoute.resolve(.memory) == .init(parent: .performance, subsection: .performance(.memory)))
        #expect(AppRoute.resolve(.processes) == .init(parent: .applications, subsection: .applications(.running)))
        #expect(AppRoute.resolve(.alerts) == .init(parent: .events, subsection: .events(.alertRules)))
    }

    @Test func primaryRoutesRemainPrimary() {
        #expect(AppRoute.resolve(.disk) == .init(parent: .disk, subsection: nil))
        #expect(AppSection.primaryNavigation.allSatisfy { AppRoute.resolve($0).parent == $0 })
    }
}
