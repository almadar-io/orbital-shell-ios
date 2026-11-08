import Foundation
import XCTest
@testable import __APP_MODULE__

final class SvgImageTests: XCTestCase {
    private let blue = Data(##"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="5"><rect width="10" height="5" fill="#0000ff"/></svg>"##.utf8)

    func testSvgIsDecidedByTheDeclaredTypeThenTheExtension() {
        XCTAssertTrue(OrbitalSvg.isSvg(url: "data:image/svg+xml;base64,AA==", contentType: "image/svg+xml"))
        XCTAssertTrue(OrbitalSvg.isSvg(url: "https://x/logo.svg?v=1", contentType: nil))
        XCTAssertFalse(OrbitalSvg.isSvg(url: "https://x/photo.png", contentType: "image/png"))
    }

    func testAnSvgPaintsAtItsPointSizeWithDisplayDensityPixels() throws {
        let image = try XCTUnwrap(OrbitalSvg.image(key: "test://blue", data: blue, pixelsPerUnit: 2))
        XCTAssertEqual(image.size, CGSize(width: 10, height: 5))
        XCTAssertEqual(image.cgImage?.width, 20)
        XCTAssertEqual(image.cgImage?.height, 10)
    }

    func testDataURLsDecodePercentEscapesAndBase64LikeTheCanvasLoader() throws {
        let percent = try XCTUnwrap(OrbitalSvg.decodeDataURL("data:image/svg+xml;utf8,%3Csvg xmlns=%22a%22/%3E"))
        XCTAssertEqual(String(decoding: percent.data, as: UTF8.self), #"<svg xmlns="a"/>"#)
        XCTAssertEqual(percent.mime, "image/svg+xml")
        let base64 = try XCTUnwrap(OrbitalSvg.decodeDataURL("data:text/plain;base64,aGk="))
        XCTAssertEqual(base64.data, Data("hi".utf8))
        XCTAssertNil(OrbitalSvg.decodeDataURL("data:image/png;base64"))
    }

    func testBytesThatAreNotSvgPaintNothing() {
        XCTAssertNil(OrbitalSvg.image(key: "test://not-svg", data: Data("plain".utf8), pixelsPerUnit: 2))
        XCTAssertNil(OrbitalSvg.image(key: "test://empty", data: Data(), pixelsPerUnit: 2))
    }
}
