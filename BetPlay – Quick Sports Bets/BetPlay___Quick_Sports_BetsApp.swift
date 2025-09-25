import SwiftUI

@main
struct BetPlayQuickSps: App {
    @StateObject private var eventsService = EventsService()
    @StateObject private var profileService = ProfileService()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventsService)
                .environmentObject(profileService)
                .onAppear {
                    profileService.bindToEvents(eventsService)
                }
        }
    }
}
