import Cocoa

@main
struct WorkspaceTests {
    static func main() {
        var workspace = Workspace(tabs: [], frameString: "{{0, 0}, {1000, 700}}")

        assert(workspace.toggleDetached(name: "Firefox", bundleIdentifier: "org.mozilla.firefox"))
        assert(workspace.tabs == [
            AppTab(name: "Firefox", bundleIdentifier: "org.mozilla.firefox", isDetached: true),
        ])

        assert(!workspace.toggleDetached(name: "Firefox", bundleIdentifier: "org.mozilla.firefox"))
        assert(!workspace.tabs[0].isDetached)
    }
}
