import XCTest
@testable import Toggle

final class PanelModelTests: XCTestCase {
    func testDefaultOrderCoversEveryToggleOnce() {
        XCTAssertEqual(ToggleID.defaultOrder.count, ToggleID.allCases.count)
        XCTAssertEqual(Set(ToggleID.defaultOrder), Set(ToggleID.allCases))
        XCTAssertEqual(ToggleID.lowPowerMode.gridTitle, "Low Power")
        XCTAssertTrue(ToggleID.mute.hasDropdown)
        XCTAssertFalse(ToggleID.wifi.hasDropdown)
    }

    func testFreshDefaultsUseGridFinderCollapsedAndEveryDuration() throws {
        let defaults = try freshDefaults()
        let state = TogglePanelState.load(from: defaults)
        XCTAssertEqual(state.viewMode, .grid)
        XCTAssertEqual(state.order, ToggleID.defaultOrder)
        XCTAssertTrue(state.hidden.isEmpty)
        XCTAssertEqual(state.collapsed, [.finderAndDock])
        XCTAssertEqual(state.keepAwakeMenu.menuMinutes, KeepAwakeDuration.allMinutes)
        XCTAssertEqual(state.keepAwakeMenu.defaultMinutes, 0)
    }

    func testOrderVisibilityViewModeAndCollapseRoundTrip() throws {
        let defaults = try freshDefaults()
        var state = TogglePanelState.standard
        state.viewMode = .list
        state = state.moving(.wifi, by: 1).settingVisible(.mute, false)
        state.collapsed = []
        state = state.settingKeepAwakeShown(15, false).settingKeepAwakeDefault(300)
        state.save(to: defaults)

        let loaded = TogglePanelState.load(from: defaults)
        XCTAssertEqual(loaded.viewMode, .list)
        XCTAssertEqual(Array(loaded.order.prefix(2)), [.bluetooth, .wifi])
        XCTAssertTrue(loaded.hidden.contains(.mute))
        XCTAssertTrue(loaded.collapsed.isEmpty)
        XCTAssertFalse(loaded.keepAwakeMenu.menuMinutes.contains(15))
        XCTAssertEqual(loaded.keepAwakeMenu.defaultMinutes, 300)
    }

    func testSanitizedOrderDropsUnknownAndDuplicatesAndAppendsMissing() {
        let order = TogglePanelState.sanitizedOrder(["mute", "nope", "mute", "wifi"])
        XCTAssertEqual(Array(order.prefix(2)), [.mute, .wifi])
        XCTAssertEqual(order.count, ToggleID.allCases.count)
        XCTAssertEqual(Set(order), Set(ToggleID.allCases))
    }

    func testInvalidViewModeFallsBackToGrid() throws {
        let defaults = try freshDefaults()
        defaults.set("tiles", forKey: "panelViewMode")
        XCTAssertEqual(TogglePanelState.load(from: defaults).viewMode, .grid)
    }

    func testMoveUpAtStartIsIgnoredAndMoveToIndexPlacesTheItem() {
        let start = TogglePanelState.standard
        XCTAssertEqual(start.moving(.wifi, by: -1).order, start.order)
        let moved = start.moving(.wifi, toIndexOf: .airPods)
        XCTAssertEqual(
            Array(moved.order.prefix(4)),
            [.bluetooth, .airDrop, .airPods, .wifi]
        )
        let fromEnd = start.moving(.airPods, toIndexOf: .wifi)
        XCTAssertEqual(fromEnd.order.first, .airPods)
    }

    func testIndexSetMoveMatchesRemovalBeforeInsertion() {
        let moved = TogglePanelState.standard.moving(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(Array(moved.order.prefix(3)), [.bluetooth, .wifi, .airDrop])
    }

    func testRestoreOrderAndVisibilityKeepsViewModeAndCollapse() {
        var state = TogglePanelState.standard
        state.viewMode = .list
        state.collapsed = []
        state = state.moving(.dockAutohide, toIndexOf: .wifi).settingVisible(.stageManager, false)
        let restored = state.restoredOrderAndVisibility()
        XCTAssertEqual(restored.order, ToggleID.defaultOrder)
        XCTAssertTrue(restored.hidden.isEmpty)
        XCTAssertEqual(restored.viewMode, .list)
        XCTAssertTrue(restored.collapsed.isEmpty)
    }

    func testDisplayedHidesItemsAndOmitsEmptySections() {
        var state = TogglePanelState.standard
        state.hidden = [.stageManager, .hideDesktopIcons, .hiddenFiles, .fileExtensions, .dockAutohide]
        var availability = ToggleAvailability.all
        availability.airPodsAvailable = false
        availability.wifiAvailable = false
        let ids = state.displayed(using: availability)
        XCTAssertFalse(ids.contains(.airPods))
        XCTAssertFalse(ids.contains(.stageManager))
        XCTAssertTrue(ids.contains(.wifi))
        XCTAssertFalse(availability.isEnabled(.wifi))
        let runs = state.sectionRuns(in: ids)
        XCTAssertEqual(
            runs.map(\.section),
            [.connectivity, .displayAndSound, .focusAndPower]
        )
        XCTAssertEqual(runs[0].ids, [.wifi, .bluetooth, .airDrop])
    }

    func testInterleavedOrderSplitsSectionRuns() {
        var state = TogglePanelState.standard
        state.order = [.darkMode, .wifi, .nightShift]
        let runs = state.sectionRuns(in: state.displayed(using: .all))
        XCTAssertEqual(
            runs.map(\.section),
            [.displayAndSound, .connectivity, .displayAndSound]
        )
    }

    func testKeepAwakeDefaultCannotBeHiddenAndEnablesOnSelection() {
        var menu = KeepAwakeMenuConfiguration.allEnabled(defaultMinutes: 60)
        menu = menu.settingShown(60, false)
        XCTAssertTrue(menu.enabled.contains(60))
        menu = menu.settingShown(15, false).settingDefault(300)
        XCTAssertFalse(menu.menuMinutes.contains(15))
        XCTAssertEqual(menu.defaultMinutes, 300)
        XCTAssertTrue(menu.menuMinutes.contains(300))
        XCTAssertEqual(menu.settingDefault(45).defaultMinutes, 300)
    }

    func testAirDropOptionsAndToggleMapping() {
        XCTAssertEqual(AirDropMenu.choices, ["Contacts Only", "Everyone", "Off"])
        let options = AirDropMenu.options(selected: "Everyone")
        XCTAssertEqual(options.first { $0.isSelected }?.id, "Everyone")
        XCTAssertEqual(AirDropMenu.toggledMode(current: "Off"), "Contacts Only")
        XCTAssertEqual(AirDropMenu.toggledMode(current: "Everyone"), "Off")
        XCTAssertTrue(AirDropMenu.isOn("Contacts Only"))
        XCTAssertFalse(AirDropMenu.isOn("Off"))
    }

    func testKeepAwakeSelectionMappingAndValueText() {
        let options = KeepAwakeMenu.options(minutes: [15, 60, 0], isOn: true, chosenMinutes: 60)
        XCTAssertEqual(options.map(\.id), ["15", "60", "0"])
        XCTAssertEqual(options.first { $0.isSelected }?.title, "1 hour")
        let off = KeepAwakeMenu.options(minutes: [60, 0], isOn: false, chosenMinutes: 60)
        XCTAssertTrue(off.allSatisfy { !$0.isSelected })
        let indefinite = KeepAwakeMenu.options(minutes: [60, 0], isOn: true, chosenMinutes: nil)
        XCTAssertEqual(indefinite.first { $0.isSelected }?.id, "0")
        XCTAssertEqual(
            KeepAwakeMenu.valueText(isOn: true, remainingMinutes: 60, indefinite: false),
            "1 hr left"
        )
        XCTAssertEqual(
            KeepAwakeMenu.valueText(isOn: true, remainingMinutes: 61, indefinite: false),
            "1 hr 1 min left"
        )
        XCTAssertEqual(
            KeepAwakeMenu.valueText(isOn: true, remainingMinutes: 15, indefinite: false),
            "15 min left"
        )
        XCTAssertEqual(
            KeepAwakeMenu.valueText(isOn: true, remainingMinutes: nil, indefinite: true),
            "Indefinitely"
        )
        XCTAssertNil(KeepAwakeMenu.valueText(isOn: false, remainingMinutes: 60, indefinite: false))
        let now = Date(timeIntervalSinceReferenceDate: 0)
        XCTAssertEqual(
            KeepAwakeMenu.remainingMinutes(until: now.addingTimeInterval(3600), now: now),
            60
        )
        XCTAssertEqual(KeepAwakeMenu.remainingMinutes(until: now, now: now.addingTimeInterval(5)), 0)
        XCTAssertEqual(
            KeepAwakeMenu.accessibilityValue(isOn: true, remainingMinutes: 42, indefinite: false),
            "On, 42 minutes remaining"
        )
        XCTAssertEqual(
            KeepAwakeMenu.accessibilityValue(isOn: true, remainingMinutes: nil, indefinite: true),
            "On indefinitely"
        )
    }

    func testDeviceMenuMarksSelectionAndTrailingAction() {
        let devices = [
            DeviceChoice(id: "a", title: "Speakers"),
            DeviceChoice(id: "b", title: "Headphones"),
        ]
        let options = DeviceMenu.options(
            devices: devices,
            selectedID: "b",
            trailingAction: DeviceChoice(id: DeviceMenu.bluetoothSettingsID, title: "Bluetooth Settings…")
        )
        XCTAssertEqual(options.map(\.id), ["a", "b", DeviceMenu.bluetoothSettingsID])
        XCTAssertEqual(options.first { $0.isSelected }?.id, "b")
        XCTAssertEqual(options.last?.isAction, true)
        XCTAssertEqual(options.last?.isSelected, false)
    }

    func testMenuHighlightClamps() {
        XCTAssertEqual(MenuKeyboard.highlight(current: 0, count: 3, delta: -1), 0)
        XCTAssertEqual(MenuKeyboard.highlight(current: 1, count: 3, delta: 1), 2)
        XCTAssertEqual(MenuKeyboard.highlight(current: 4, count: 3, delta: 1), 3)
    }

    func testGridFocusMovesAcrossRowsAndCollapsedSections() {
        let runs = [
            ToggleRun(section: .connectivity, ids: Array(ToggleID.defaultOrder.prefix(5))),
        ]
        let map = PanelFocusMap.grid(runs: runs, collapsed: [])
        XCTAssertEqual(map.rows[0], [.section(.connectivity)])
        XCTAssertEqual(map.rows[1].count, 4)
        XCTAssertEqual(map.rows[2].count, 1)
        let firstTile = map.rows[1][0]
        XCTAssertEqual(map.moved(nil, direction: .down), .section(.connectivity))
        XCTAssertEqual(map.moved(firstTile, direction: .right), map.rows[1][1])
        XCTAssertEqual(map.moved(map.rows[1][3], direction: .right), map.rows[2][0])
        XCTAssertEqual(map.moved(map.rows[1][1], direction: .down), map.rows[2][0])
        let collapsed = PanelFocusMap.grid(runs: runs, collapsed: [.connectivity])
        XCTAssertEqual(collapsed.rows[0], [.section(.connectivity)])
        XCTAssertEqual(collapsed.rows[1].count, QuickAction.allCases.count)
    }

    func testListFocusUsesVerticalMovementOnly() {
        let ids: [ToggleID] = [.wifi, .bluetooth]
        let map = PanelFocusMap.list(ids: ids)
        XCTAssertEqual(map.moved(.tile(.wifi), direction: .down), .tile(.bluetooth))
        XCTAssertEqual(map.moved(.tile(.wifi), direction: .right), .tile(.wifi))
        XCTAssertEqual(map.moved(.tile(.bluetooth), direction: .down), .action(.screenSaver))
    }

    @MainActor
    func testModelPersistsViewModeVisibilityAndDefaultDuration() throws {
        let defaults = try freshDefaults()
        let model = TogglePanelModel(defaults: defaults)
        model.viewMode = .list
        model.setVisible(.stageManager, false)
        model.setKeepAwakeDefault(60)
        model.toggleCollapsed(.finderAndDock)
        let reloaded = TogglePanelModel(defaults: defaults)
        XCTAssertEqual(reloaded.viewMode, .list)
        XCTAssertTrue(reloaded.state.hidden.contains(.stageManager))
        XCTAssertEqual(reloaded.state.keepAwakeMenu.defaultMinutes, 60)
        XCTAssertFalse(reloaded.state.collapsed.contains(.finderAndDock))
    }

    private func freshDefaults() throws -> UserDefaults {
        let suite = "TogglePanelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
