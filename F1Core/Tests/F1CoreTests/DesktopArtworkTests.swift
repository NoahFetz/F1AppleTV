import XCTest
@testable import F1Core

final class DesktopArtworkTests: XCTestCase {
    func testWideRetinaArtworkStaysWithinProviderLimit() throws {
        let request = try XCTUnwrap(CatalogArtworkRequest(pictureID: "fixture/landscape_web", size: CGSize(width: 3200, height: 400), scale: 2, maximumPixelDimension: 2560))
        XCTAssertEqual(request.pixelSize, CGSize(width: 2560, height: 320))
        let query = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first { $0.name == "w" }?.value, "2560")
    }
    func testPortraitLimitRetainsAspectRatioAndNormalRequestsStayUnchanged() throws {
        let request = try XCTUnwrap(CatalogArtworkRequest(pictureID: "fixture", size: CGSize(width: 400, height: 3200), scale: 2, maximumPixelDimension: 2560))
        XCTAssertEqual(request.pixelSize, CGSize(width: 320, height: 2560))
        let ordinary = CatalogArtworkRequest(pictureID: "fixture", size: CGSize(width: 280, height: 158), scale: 2)
        XCTAssertEqual(ordinary, CatalogArtworkRequest(pictureID: "fixture", size: CGSize(width: 280, height: 158), scale: 2, maximumPixelDimension: 2560))
        XCTAssertEqual(CatalogArtworkRequest(pictureID: "fixture", size: CGSize(width: 3200, height: 400), scale: 2)?.pixelSize.width, 6400)
    }
    func testInvalidProviderLimitsAreRejected() {
        for limit in [CGFloat.nan, .infinity, -1, 0, 7] {
            XCTAssertNil(CatalogArtworkRequest(pictureID: "fixture", size: CGSize(width: 100, height: 100), scale: 2, maximumPixelDimension: limit))
        }
    }
}
