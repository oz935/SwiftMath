import XCTest
@testable import SwiftMath

// The four commands this fork adds over 1.7.3 (\iint, \boldsymbol and \pmod
// cherry-picked from upstream main; \underbrace written here). The first four
// inputs are the Nice TeX corpus rows that 1.7.3 failed, verbatim.
final class AddedCommandsTests: XCTestCase {

    private let font = MTFontManager.fontManager.latinModernFont(withSize: 14)!

    private func parse(_ tex: String, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathList {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: tex, error: &error)
        XCTAssertNil(error, "\(tex): \(String(describing: error))", file: file, line: line)
        return try XCTUnwrap(list, file: file, line: line)
    }

    private func typeset(_ tex: String, style: MTLineStyle = .display, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathListDisplay {
        let list = try parse(tex, file: file, line: line)
        let display = try XCTUnwrap(MTTypesetter.createLineForMathList(list, font: font, style: style), file: file, line: line)
        XCTAssertGreaterThan(display.width, 0, tex, file: file, line: line)
        return display
    }

    func testCorpusRowsTypeset() throws {
        for tex in [
            "\\boldsymbol{\\alpha} + \\mathbf{v}",
            "\\iint_{D} f(x,y) \\, dA",
            "\\{ x \\in \\mathbb{Z} : x \\equiv 1 \\pmod{3} \\}",
            "\\underbrace{1 + 2 + \\cdots + n}_{n \\text{ terms}}",
        ] {
            _ = try typeset(tex)
            _ = try typeset(tex, style: .text)
        }
    }

    func testNewcommandStaysAParseError() {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: "\\newcommand{\\R}{\\mathbb{R}} f: \\R \\to \\R", error: &error)
        XCTAssertNotNil(error)
    }

    func testBoldsymbolIsBoldItalic() throws {
        let list = try parse("\\boldsymbol{\\alpha}")
        XCTAssertEqual(list.atoms.first?.fontStyle, .boldItalic)
    }

    func testIintIsTheDoubleIntegralOperator() throws {
        let op = try XCTUnwrap(try parse("\\iint").atoms.first as? MTLargeOperator)
        XCTAssertEqual(op.nucleus, "\u{222C}")
        XCTAssertFalse(op.limits)
    }

    func testPmodIsParenthesisedMod() throws {
        let inner = try XCTUnwrap(try parse("\\pmod{3}").atoms.first as? MTInner)
        XCTAssertEqual(inner.leftBoundary?.nucleus, "(")
        XCTAssertEqual(inner.rightBoundary?.nucleus, ")")
        XCTAssertEqual(inner.innerList?.atoms.first?.nucleus, "mod")
    }

    func testUnderbraceParsesWithItsLabel() throws {
        let brace = try XCTUnwrap(try parse("\\underbrace{a+b}_{n}").atoms.first as? MTUnderBrace)
        XCTAssertEqual(brace.type, .largeOperator)
        XCTAssertTrue(brace.limits)
        XCTAssertEqual(brace.innerList?.atoms.count, 3)
        XCTAssertEqual(brace.subScript?.atoms.first?.nucleus, "n")
    }

    func testUnderbraceRoundTripsAndCopies() throws {
        let list = try parse("\\underbrace{a+b}_{n}")
        XCTAssertEqual(MTMathListBuilder.mathListToString(list), "\\underbrace{a+b}_{n}")
        let copy = try XCTUnwrap(list.atoms.first?.copy() as? MTUnderBrace)
        XCTAssertEqual(copy.innerList?.atoms.count, 3)
        let finalized = try XCTUnwrap(list.finalized.atoms.first as? MTUnderBrace)
        XCTAssertEqual(finalized.innerList?.atoms.count, 3)
        XCTAssertEqual(MTMathListBuilder.mathListToString(list.finalized), "\\underbrace{a+b}_{n}")
    }

    func testUnderbraceSitsBelowTheContentAndTheLabelBelowTheBrace() throws {
        for style in [MTLineStyle.display, .text] {
            let plain = try typeset("a+b", style: style)
            let braced = try typeset("\\underbrace{a+b}", style: style)
            let labelled = try typeset("\\underbrace{a+b}_{n}", style: style)
            XCTAssertEqual(braced.ascent, plain.ascent, accuracy: 0.01)
            XCTAssertGreaterThan(braced.descent, plain.descent + 2)
            // The label goes under the brace in text style too (\limits).
            XCTAssertGreaterThan(labelled.descent, braced.descent + 2)
            XCTAssertEqual(labelled.ascent, braced.ascent, accuracy: 0.01)
            XCTAssertNotNil(labelled.subDisplays.first as? MTLargeOpLimitsDisplay)
        }
    }

    func testBraceIsAtLeastAsWideAsItsContent() throws {
        // Short content uses a font variant; long content (wider than the
        // largest, about 4 em) is assembled from the font's parts.
        for tex in ["x", "a+b", "1 + 2 + \\cdots + n", "1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12"] {
            let content = try typeset(tex)
            let display = try XCTUnwrap(try typeset("\\underbrace{\(tex)}").subDisplays.first as? MTUnderBraceDisplay)
            let brace = display.brace
            let braceWidth: CGFloat
            if let glyph = brace as? MTGlyphDisplay {
                var g: CGGlyph = glyph.glyph
                braceWidth = CTFontGetAdvancesForGlyphs(font.ctFont, .horizontal, &g, nil, 1)
            } else {
                let run = try XCTUnwrap(brace as? MTGlyphConstructionDisplay)
                var advances = [CGSize](repeating: .zero, count: run.numGlyphs)
                CTFontGetAdvancesForGlyphs(font.ctFont, .horizontal, run.glyphs, &advances, run.numGlyphs)
                braceWidth = zip(run.positions, advances).map { $0.x + $1.width }.max()!
                XCTAssertEqual(run.positions.first?.x, 0)
            }
            XCTAssertGreaterThanOrEqual(braceWidth + 0.01, content.width, tex)
            XCTAssertEqual(display.width, max(content.width, braceWidth), accuracy: 0.01)
        }
        let long = try XCTUnwrap(try typeset("\\underbrace{1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12}").subDisplays.first as? MTUnderBraceDisplay)
        XCTAssertTrue(long.brace is MTGlyphConstructionDisplay, "long content must use the assembly")
    }

    func testEmptyAndMissingArgumentsDoNotTrap() throws {
        _ = try XCTUnwrap(MTTypesetter.createLineForMathList(try parse("\\underbrace{}"), font: font, style: .display))
        var error: NSError?
        if let list = MTMathListBuilder.build(fromString: "\\underbrace", error: &error) {
            _ = MTTypesetter.createLineForMathList(list, font: font, style: .display)
        }
    }

    func testUnderbraceDrawsBelowTheBaseline() throws {
        let display = try typeset("\\underbrace{a+b}_{n}")
        display.textColor = MTColor.black
        let height = Int(ceil(display.ascent + display.descent)) + 4
        let width = Int(ceil(display.width)) + 4
        display.position = CGPoint(x: 2, y: 2 + display.descent)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        display.draw(context)
        // Ink in the lowest third (the label) and in the band just under the
        // content's baseline (the brace): the brace and label really draw.
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        func inked(rows: Range<Int>) -> Bool {
            rows.contains { row in (0..<width).contains { data[row * context.bytesPerRow + $0] < 128 } }
        }
        // Bitmap rows run top-down; the baseline is `descent + 2` from the bottom.
        let baselineRow = height - Int(2 + display.descent)
        XCTAssertTrue(inked(rows: baselineRow + 1 ..< height - 2), "nothing drawn below the baseline")
        XCTAssertTrue(inked(rows: 0 ..< baselineRow), "nothing drawn above the baseline")
    }
}
