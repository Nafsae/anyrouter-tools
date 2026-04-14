import XCTest
@testable import AnyRouterManager

final class AccountFormViewModelTests: XCTestCase {
    @MainActor
    func testNormalizedCookieInputPreservesRawCookieHeader() {
        let vm = AccountFormViewModel()
        let raw = "session=abc123; acw_tc=tc-value; cdn_sec_tc=cdn-value"

        XCTAssertEqual(vm.normalizedCookieInput(raw), raw)
    }

    @MainActor
    func testSessionValueCanStillBeExtractedFromCookieHeader() {
        let vm = AccountFormViewModel()
        let raw = "session=abc123; acw_tc=tc-value"

        XCTAssertEqual(vm.sessionValue(from: raw), "abc123")
    }
}
