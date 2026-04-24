import XCTest
@testable import AmneziaCloakCore

final class TunnelNameTests: XCTestCase {

    func testAcceptsSimpleName() {
        XCTAssertEqual(validatedTunnelName("narek_ios"), "narek_ios")
        XCTAssertEqual(validatedTunnelName("mac"), "mac")
        XCTAssertEqual(validatedTunnelName("A1-b2_c3"), "A1-b2_c3")
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(validatedTunnelName("  phone  "), "phone")
        XCTAssertEqual(validatedTunnelName("\tphone\n"), "phone")
    }

    func testRejectsEmpty() {
        XCTAssertNil(validatedTunnelName(""))
        XCTAssertNil(validatedTunnelName("   "))
    }

    func testRejectsTooLong() {
        // 15 chars is the upper bound.
        XCTAssertEqual(validatedTunnelName("a23456789012345"), "a23456789012345")
        XCTAssertNil(validatedTunnelName("a234567890123456"))
    }

    func testRejectsInvalidChars() {
        XCTAssertNil(validatedTunnelName("name with space"))
        XCTAssertNil(validatedTunnelName("name.dot"))
        XCTAssertNil(validatedTunnelName("name/slash"))
        XCTAssertNil(validatedTunnelName("name!"))
        XCTAssertNil(validatedTunnelName("name😀"))
    }
}
