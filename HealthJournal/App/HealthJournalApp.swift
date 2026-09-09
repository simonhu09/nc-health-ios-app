// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
@main struct HealthJournalApp:App {@StateObject private var store=AppStore();var body:some Scene{WindowGroup{RootView().environmentObject(store)}}}
