import AppKit
import XCTest
@testable import ClipartBrowserCore

final class ImageTrimmerTests: XCTestCase {
    func testTrimsWhitePaddingAroundOpaqueArtwork() throws {
        let source = try makeTestPNG(width: 5, height: 5) { x, y in
            if (1...3).contains(x), (1...3).contains(y) {
                return NSColor.systemRed
            }
            return NSColor.white
        }

        let output = try XCTUnwrap(ImageTrimmer.trimmedPNGData(from: source, whiteTolerance: 250))
        let image = try XCTUnwrap(NSImage(data: output))

        XCTAssertEqual(Int(image.size.width), 3)
        XCTAssertEqual(Int(image.size.height), 3)
    }
}

func makeTestPNG(width: Int, height: Int, color: (Int, Int) -> NSColor) throws -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
    let bitmap = try XCTUnwrap(rep)
    let data = try XCTUnwrap(bitmap.bitmapData)
    for y in 0..<height {
        for x in 0..<width {
            let deviceColor = try XCTUnwrap(color(x, y).usingColorSpace(.deviceRGB))
            let offset = y * bitmap.bytesPerRow + x * 4
            data[offset] = UInt8((deviceColor.redComponent * 255).rounded())
            data[offset + 1] = UInt8((deviceColor.greenComponent * 255).rounded())
            data[offset + 2] = UInt8((deviceColor.blueComponent * 255).rounded())
            data[offset + 3] = UInt8((deviceColor.alphaComponent * 255).rounded())
        }
    }
    return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
}
