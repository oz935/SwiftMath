import XCTest
@testable import SwiftMath

// This fork ships Latin Modern Math only. These tests fail if a font file
// comes back without its enum case and licence, or a case without its file.
final class FontBundleTests: XCTestCase {

    func testBundleHoldsLatinModernAndItsLicencesOnly() throws {
        let url = try XCTUnwrap(MTFont.fontBundle.resourceURL)
        let files = try FileManager.default.contentsOfDirectory(atPath: url.path)
            .filter { $0 != "Info.plist" && !$0.hasPrefix(".") }
            .sorted()
        XCTAssertEqual(files, [
            "GUST-FONT-LICENSE.txt",
            "LICENSE",
            "latinmodern-math.otf",
            "latinmodern-math.plist",
        ])
    }

    func testEveryMathFontCaseHasItsFiles() {
        XCTAssertEqual(MathFont.allCases, [.latinModernFont])
        for font in MathFont.allCases {
            XCTAssertNotNil(MTFont.fontBundle.path(forResource: font.rawValue, ofType: "otf"))
            XCTAssertNotNil(MTFont.fontBundle.path(forResource: font.rawValue, ofType: "plist"))
        }
    }

    func testUnknownFontNameIsNilNotATrap() {
        XCTAssertNil(MTFontManager.fontManager.font(withName: "xits-math", size: 20))
        XCTAssertNotNil(MTFontManager.fontManager.latinModernFont(withSize: 20))
        XCTAssertNotNil(MTFontManager.fontManager.defaultFont)
    }
}
