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

    /// Dark pixels after drawing `tex` into a white bitmap that is NOT the
    /// platform's current graphics context, with the context's own fill and
    /// stroke colours left white, so only the display's colour can ink.
    private func inkedPixels(_ tex: String) throws -> Int {
        let display = try typeset(tex)
        display.textColor = MTColor.black
        display.position = CGPoint(x: 4, y: 4 + display.descent)
        let width = Int(ceil(display.width)) + 8
        let height = Int(ceil(display.ascent + display.descent)) + 8
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(gray: 1, alpha: 1)
        display.draw(context)
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return (0..<height).reduce(0) { total, row in
            // Any ink counts: at 14 pt a rule is under a pixel thick, so its
            // anti-aliased pixels are light grey.
            total + (0..<width).filter { data[row * context.bytesPerRow + $0] < 250 }.count
        }
    }

    func testGlyphsAndRulesDrawInTheDisplaysColourIntoAnyContext() throws {
        // Glyph-only displays (a large operator, stretched delimiters).
        XCTAssertGreaterThan(try inkedPixels("\\iint"), 0)
        XCTAssertGreaterThan(try inkedPixels("\\left( x \\right)"), try inkedPixels("x"))
        // Rules: overline, underline, fraction bar, radical sign and overbar.
        XCTAssertGreaterThan(try inkedPixels("\\overline{x}"), try inkedPixels("x"))
        XCTAssertGreaterThan(try inkedPixels("\\underline{x}"), try inkedPixels("x"))
        XCTAssertGreaterThan(try inkedPixels("\\frac{a}{b}"), try inkedPixels("ab"))
        XCTAssertGreaterThan(try inkedPixels("\\sqrt{xx}"), try inkedPixels("xx") + 20)
    }
}
