import Quick
import Nimble
import Cocoa
@testable import Clipy

class ClipDataSpec: QuickSpec {
    override class func spec() {

        describe("hash") {

            it("matches for the same file copy with reordered pasteboard types") {
                let first = CPYClipData(image: NSImage(size: NSSize(width: 1, height: 1)))
                first.image = nil
                first.types = [.deprecatedFilenames, .deprecatedURL, .deprecatedString]
                first.fileNames = ["/tmp/example.png"]
                first.URLs = ["file:///tmp/example.png"]
                first.stringValue = "example.png"

                let second = CPYClipData(image: NSImage(size: NSSize(width: 1, height: 1)))
                second.image = nil
                second.types = [.deprecatedString, .deprecatedFilenames, .deprecatedURL]
                second.fileNames = ["/tmp/example.png"]
                second.URLs = ["file:///tmp/example.png"]
                second.stringValue = "example.png"

                expect(first.hash) == second.hash
            }

        }

    }
}
