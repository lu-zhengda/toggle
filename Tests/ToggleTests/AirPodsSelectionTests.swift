import XCTest
@testable import Toggle

final class AirPodsSelectionTests: XCTestCase {
    func testEligibilityExcludesFindMyCompanionRecords() {
        XCTAssertTrue(AirPodsSelectionPolicy.isEligible(name: "AirPods Pro"))
        XCTAssertTrue(AirPodsSelectionPolicy.isEligible(name: "Jane's AirPods"))
        XCTAssertFalse(AirPodsSelectionPolicy.isEligible(name: "Jane's AirPods - Find My"))
        XCTAssertFalse(AirPodsSelectionPolicy.isEligible(name: "FIND MY AIRPODS"))
        XCTAssertFalse(AirPodsSelectionPolicy.isEligible(name: "Bluetooth Headphones"))
    }

    func testConnectedDeviceWinsOverDisconnectedPreference() {
        let devices = [
            device("preferred", connected: false),
            device("connected", connected: true),
        ]

        XCTAssertEqual(
            AirPodsSelectionPolicy.selectedID(
                devices: devices,
                preferredID: "preferred"
            ),
            "connected"
        )
    }

    func testPreferredDeviceWinsWhenMultipleDevicesAreConnected() {
        let devices = [
            device("first", connected: true),
            device("preferred", connected: true),
        ]

        XCTAssertEqual(
            AirPodsSelectionPolicy.selectedID(
                devices: devices,
                preferredID: "preferred"
            ),
            "preferred"
        )
    }

    func testPreferenceWinsWhenNothingIsConnected() {
        let devices = [device("first"), device("preferred")]

        XCTAssertEqual(
            AirPodsSelectionPolicy.selectedID(
                devices: devices,
                preferredID: "preferred"
            ),
            "preferred"
        )
    }

    func testOnlyDeviceIsSelectedWithoutPreference() {
        XCTAssertEqual(
            AirPodsSelectionPolicy.selectedID(
                devices: [device("only")],
                preferredID: nil
            ),
            "only"
        )
    }

    func testMultipleDisconnectedDevicesRequireChooserWithoutPreference() {
        XCTAssertNil(
            AirPodsSelectionPolicy.selectedID(
                devices: [device("first"), device("second")],
                preferredID: nil
            )
        )
    }

    private func device(
        _ id: String,
        connected: Bool = false
    ) -> AirPodsDevice {
        AirPodsDevice(id: id, name: id, isConnected: connected)
    }
}
