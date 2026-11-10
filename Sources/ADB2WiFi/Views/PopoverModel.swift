import Observation

/// Popover UI state that outlives a single view instance. The status-item menu uses it
/// to open Settings directly without rebuilding the popover.
@MainActor
@Observable
final class PopoverModel {
    var showingSettings: Bool

    init(showingSettings: Bool = false) {
        self.showingSettings = showingSettings
    }
}
