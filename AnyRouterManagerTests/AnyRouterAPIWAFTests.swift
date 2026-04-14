import XCTest
@testable import AnyRouterManager

final class AnyRouterAPIWAFTests: XCTestCase {
    func testParseCookieHeaderExtractsSessionAndWafCookies() {
        let cookies = AnyRouterAPI.parseCookieHeader(
            "session=abc123; acw_tc=tc-value; cdn_sec_tc=cdn-value; acw_sc__v2=sc-value"
        )

        XCTAssertEqual(cookies["session"], "abc123")
        XCTAssertEqual(cookies["acw_tc"], "tc-value")
        XCTAssertEqual(cookies["cdn_sec_tc"], "cdn-value")
        XCTAssertEqual(cookies["acw_sc__v2"], "sc-value")
    }

    func testParseCookieHeaderTreatsBareValueAsSession() {
        let cookies = AnyRouterAPI.parseCookieHeader("plain-session-value")

        XCTAssertEqual(cookies["session"], "plain-session-value")
    }
}
