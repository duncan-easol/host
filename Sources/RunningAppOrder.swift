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
