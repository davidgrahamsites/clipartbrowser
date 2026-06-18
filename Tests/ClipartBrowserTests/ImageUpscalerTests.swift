import AppKit
import XCTest
@testable import ClipartBrowserCore

final class ImageUpscalerTests: XCTestCase {
    func testEachMethodUpscalesToTargetDimensions() throws {
        let source = try makeTestPNG(width: 8, height: 8) { x, y in
            (x + y).isMultiple(of: 2) ? NSColor.systemBlue : NSColor.white
        }
        let target = CGSize(width: 64, height: 48)

        for method in ImageResizeMethod.allCases {
            let output = try XCTUnwrap(
                ImageUpscaler.resized(source, to: target, using: method),
                "\(method.displayName) returned nil"
            )
            let image = try XCTUnwrap(NSImage(data: output))
            let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            XCTAssertEqual(cgImage.width, 64, "\(method.displayName) width")
            XCTAssertEqual(cgImage.height, 48, "\(method.displayName) height")
        }
    }

    func testDoesNotShrinkBelowSourceResolution() throws {
        let source = try makeTestPNG(width: 32, height: 32) { _, _ in NSColor.systemRed }
        let target = CGSize(width: 8, height: 8)

        for method in ImageResizeMethod.allCases {
            let output = try XCTUnwrap(ImageUpscaler.resized(source, to: target, using: method))
            // Upscale-only: smaller target is a no-op that returns the original bytes.
            XCTAssertEqual(output, source, "\(method.displayName) should not downscale")
        }
    }
}
