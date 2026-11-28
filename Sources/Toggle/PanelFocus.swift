import Foundation

enum QuickAction: String, CaseIterable, Hashable, Sendable {
    case screenSaver
    case lockScreen
    case sleepDisplay
    case more

    var title: String {
        switch self {
        case .screenSaver: "Screen Saver"
        case .lockScreen: "Lock Screen"
        case .sleepDisplay: "Sleep Display"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .screenSaver: "display"
        case .lockScreen: "lock.fill"
        case .sleepDisplay: "moon.zzz.fill"
        case .more: "ellipsis"
        }
    }
}

enum PanelTarget: Hashable, Sendable {
    case section(ToggleSection)
    case tile(ToggleID)
    case action(QuickAction)
}

enum FocusDirection: Sendable {
    case up
    case down
    case left
    case right
}

struct PanelFocusMap: Equatable, Sendable {
    var rows: [[PanelTarget]]
    var allowsHorizontal: Bool

    static func grid(
        runs: [ToggleRun],
        collapsed: Set<ToggleSection>,
        columns: Int = 4
    ) -> PanelFocusMap {
        var rows: [[PanelTarget]] = []
        let width = max(1, columns)
        for run in runs {
            rows.append([.section(run.section)])
            if collapsed.contains(run.section) { continue }
            var index = 0
            while index < run.ids.count {
                let end = min(index + width, run.ids.count)
                rows.append(run.ids[index..<end].map { .tile($0) })
                index = end
            }
        }
        rows.append(QuickAction.allCases.map { .action($0) })
        return PanelFocusMap(rows: rows, allowsHorizontal: true)
    }

    static func list(ids: [ToggleID]) -> PanelFocusMap {
        let tileRows = ids.map { [PanelTarget.tile($0)] }
        let actionRows = QuickAction.allCases.map { [PanelTarget.action($0)] }
        return PanelFocusMap(rows: tileRows + actionRows, allowsHorizontal: false)
    }

    func moved(_ current: PanelTarget?, direction: FocusDirection) -> PanelTarget? {
        guard let first = rows.first?.first else { return nil }
        guard let current, let position = index(of: current) else { return first }
        let row = position.row
        let column = position.column
        switch direction {
        case .left:
            guard allowsHorizontal else { return current }
            if column > 0 { return rows[row][column - 1] }
            if row > 0, let previous = rows[row - 1].last { return previous }
            return current
        case .right:
            guard allowsHorizontal else { return current }
            if column + 1 < rows[row].count { return rows[row][column + 1] }
            if row + 1 < rows.count, let next = rows[row + 1].first { return next }
            return current
        case .up:
            guard row > 0 else { return current }
            let above = rows[row - 1]
            return above[min(column, above.count - 1)]
        case .down:
            guard row + 1 < rows.count else { return current }
            let below = rows[row + 1]
            return below[min(column, below.count - 1)]
        }
    }

    private func index(of target: PanelTarget) -> (row: Int, column: Int)? {
        for (row, items) in rows.enumerated() {
            if let column = items.firstIndex(of: target) {
                return (row, column)
            }
        }
        return nil
    }
}
