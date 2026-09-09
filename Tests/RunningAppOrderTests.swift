import Foundation

@main
struct RunningAppOrderTests {
    static func main() {
        assert(runningAppOrder(eligible: ["mail", "notes", "mail"], previous: []) == ["mail", "notes"])
        assert(runningAppOrder(eligible: ["mail", "notes", "music"],
                               previous: ["notes", "mail"],
                               activated: "music") == ["music", "notes", "mail"])
        assert(runningAppOrder(eligible: ["mail", "music"],
                               previous: ["music", "notes", "mail"]) == ["music", "mail"])
        assert(runningAppOrder(eligible: ["mail", "notes"],
                               previous: ["mail", "notes"],
                               activated: "finder") == ["mail", "notes"])
        assert(labelledRunningAppIDs(order: ["mail", "notes", "music"], limit: 2)
            == Set(["mail", "notes"]))
        assert(labelledRunningAppIDs(order: ["music", "mail", "notes"], limit: 2)
            == Set(["music", "mail"]))
        assert(labelledRunningAppIDs(order: ["mail"], limit: 0).isEmpty)

        var cycle = RunningAppCycle()
        assert(cycle.next(liveOrder: ["mail", "notes", "music"], current: "mail",
                          offset: 1, restart: true) == "notes")
        // The live order changes after Notes activates, but this burst continues
        // through the original snapshot instead of returning to Mail.
        assert(cycle.next(liveOrder: ["notes", "mail", "music"], current: "notes",
                          offset: 1, restart: false) == "music")
        assert(cycle.next(liveOrder: ["music", "notes", "mail"], current: "music",
                          offset: 1, restart: false) == "mail")
        cycle.reset()
        assert(cycle.next(liveOrder: ["music", "notes", "mail"], current: "music",
                          offset: -1, restart: true) == "mail")
    }
}
