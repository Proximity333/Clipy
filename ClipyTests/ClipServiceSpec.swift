import Quick
import Nimble
import Cocoa
@testable import Clipy

class ClipServiceSpec: QuickSpec {
    override class func spec() {

        describe("clip data text parsing") {

            it("reads text from modern pasteboard string types") {
                let pasteboard = NSPasteboard.withUniqueName()
                pasteboard.declareTypes([.utf8PlainText], owner: nil)
                pasteboard.setString("hello world", forType: .utf8PlainText)

                let data = CPYClipData(pasteboard: pasteboard, types: [.utf8PlainText])

                expect(data.stringValue) == "hello world"
                expect(data.hasMeaningfulContent) == true
            }

        }

    }
}
