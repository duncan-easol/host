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
        assert(cycle.preview(liveOrder: ["mail", "notes", "music"], current: "mail",
                             offset: 1) == "notes")
        // Previewing does not commit. Further presses continue through the stable
        // snapshot even if the live MRU order changes underneath it.
        assert(cycle.preview(liveOrder: ["notes", "mail", "music"], current: "mail",
                             offset: 1) == "music")
        assert(cycle.preview(liveOrder: ["music", "notes", "mail"], current: "mail",
                             offset: -1) == "notes")
        assert(cycle.commit() == "notes")
        assert(cycle.commit() == nil)
        assert(cycle.preview(liveOrder: ["music", "notes", "mail"], current: "music",
                             offset: -1) == "mail")
    }
}
