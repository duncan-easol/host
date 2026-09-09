import Foundation

/// Keep eligible app identifiers in most-recently-used order.
///
/// `seed` comes from the Window Server's front-to-back window order at launch.
/// After that, activation notifications provide the exact order.
func runningAppOrder(eligible: [String], previous: [String], activated: String? = nil) -> [String] {
    var seen = Set<String>()
    let eligible = eligible.filter { seen.insert($0).inserted }
    let eligibleSet = Set(eligible)
    var order = previous.filter { eligibleSet.contains($0) }

    if let activated, eligibleSet.contains(activated) {
        order.removeAll { $0 == activated }
        order.insert(activated, at: 0)
    }

    let retained = Set(order)
    order.append(contentsOf: eligible.filter { !retained.contains($0) })
    return order
}

/// The leading MRU entries get labels; the rest use compact icon buttons.
func labelledRunningAppIDs(order: [String], limit: Int) -> Set<String> {
    Set(order.prefix(max(0, limit)))
}

/// A stable view of the MRU list for one burst of shortcut presses.
///
/// Activating an app immediately promotes it in the live MRU list. Cycling over
/// that changing list would bounce between two apps, so a burst keeps its starting
/// order until the controller resets it after a short pause.
struct RunningAppCycle {
    private var snapshot: [String] = []
    private var index: Int?

    mutating func next(liveOrder: [String], current: String?, offset: Int,
                       restart: Bool) -> String? {
        if restart || snapshot.isEmpty {
            snapshot = liveOrder
            index = current.flatMap { snapshot.firstIndex(of: $0) }
        }
        guard let next = relativeTabIndex(activeIndex: index, tabCount: snapshot.count,
                                          offset: offset) else { return nil }
        index = next
        return snapshot[next]
    }

    mutating func reset() {
        snapshot.removeAll()
        index = nil
    }
}
