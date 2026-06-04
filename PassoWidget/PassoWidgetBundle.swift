import WidgetKit
import SwiftUI

/// WidgetKit entry point. Add more widgets to the bundle as the app grows
/// (e.g. a card-balance widget, a Lock Screen accessory).
@main
struct PassoWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        TicketLiveActivity()
    }
}
