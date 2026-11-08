import Foundation
import XCTest
@testable import __APP_MODULE__

final class ClassUtilityTests: XCTestCase {
    func testDisplayTokensResolveMobileFirst() {
        XCTAssertFalse(almadarClassVisible("hidden md:flex", at: 400))
        XCTAssertTrue(almadarClassVisible("hidden md:flex", at: AlmadarBreakpoints.md))
        XCTAssertTrue(almadarClassVisible("px-8", at: 400))
    }

    func testShrinkZeroHoldsUntilAReachedBreakpointRestoresShrinking() {
        XCTAssertTrue(almadarClassNoShrink("shrink-0 px-8", at: 400))
        XCTAssertFalse(almadarClassNoShrink("px-8", at: 400))
        XCTAssertTrue(almadarClassNoShrink("shrink-0 md:shrink", at: 400))
        XCTAssertFalse(almadarClassNoShrink("shrink-0 md:shrink", at: AlmadarBreakpoints.md))
        XCTAssertFalse(almadarClassNoShrink("shrink-10", at: 400))
    }

    func testNowrapHoldsUntilAnotherWhitespaceTokenApplies() {
        XCTAssertTrue(almadarClassNoWrap("whitespace-nowrap", at: 400))
        XCTAssertFalse(almadarClassNoWrap("text-balance", at: 400))
        XCTAssertFalse(almadarClassNoWrap("whitespace-nowrap lg:whitespace-normal", at: AlmadarBreakpoints.lg))
        XCTAssertTrue(almadarClassNoWrap("sm:whitespace-nowrap", at: AlmadarBreakpoints.sm))
        XCTAssertFalse(almadarClassNoWrap("sm:whitespace-nowrap", at: 400))
    }
}
