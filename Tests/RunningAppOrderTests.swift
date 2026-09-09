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
    }
}
