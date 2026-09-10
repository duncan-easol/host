import Cocoa

@main
struct TabButtonTests {
    static func main() {
        let button = TabButton(frame: .zero)
        assert(button.acceptsFirstMouse(for: nil))
    }
}
