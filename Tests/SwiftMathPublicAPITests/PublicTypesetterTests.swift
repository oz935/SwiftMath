import CoreGraphics
import XCTest
import SwiftMath  // deliberately NOT @testable: this target proves the public surface

// Typesets without any MTMathUILabel, using only public API, the way a host
// that owns its own CGContext (a bitmap layer, a thumbnail renderer) does.
final class PublicTypesetterTests: XCTestCase {

    private func typeset(_ tex: String) throws -> MTMathListDisplay {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: tex, error: &error)
        XCTAssertNil(error, "parse error for \(tex): \(String(describing: error))")
        let font = try XCTUnwrap(MTFontManager.manager.latinModernFont(withSize: 14))
        return try XCTUnwrap(MTTypesetter.createLineForMathList(list, font: font, style: .display))
    }

    func testTypesetsAndMeasuresWithoutAView() throws {
        let display = try typeset("x^2 + \\frac{a}{b}")
        XCTAssertGreaterThan(display.width, 0)
        XCTAssertGreaterThan(display.ascent, 0)
        XCTAssertGreaterThanOrEqual(display.descent, 0)
    }

    func testDrawsIntoAPlainBitmapContext() throws {
        let display = try typeset("\\sqrt{x}")
        display.textColor = MTColor.black
        display.position = CGPoint(x: 2, y: 2 + display.descent)
        XCTAssertEqual(display.position.x, 2)

        let width = Int(ceil(display.width)) + 4
        let height = Int(ceil(display.ascent + display.descent)) + 4
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        display.draw(context)

        // Something other than the white background was drawn.
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let inked = (0..<(context.bytesPerRow * height)).contains { data[$0] < 128 }
        XCTAssertTrue(inked, "the display drew nothing into the context")
    }
}
