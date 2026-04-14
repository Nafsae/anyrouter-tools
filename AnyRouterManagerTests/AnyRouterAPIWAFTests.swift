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

    func testChallengeHtmlIsDetectedAsWafPage() {
        let html = "<html><script>var arg1='84E4F48DF2C67F59FE1FE70CC566D1BE649AE88E';</script></html>"

        XCTAssertTrue(AnyRouterAPI.isWAFChallengePage(data: Data(html.utf8)))
    }

    func testUnauthorizedJsonIsNotDetectedAsWafPage() {
        let json = #"{"message":"无权进行此操作，未登录且未提供 access token","success":false}"#

        XCTAssertFalse(AnyRouterAPI.isWAFChallengePage(data: Data(json.utf8)))
    }
}
