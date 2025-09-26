import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            BettingView()
                .tabItem {
                    Image(systemName: "sportscourt")
                    Text("Bets")
                }

            MiniGamesHubView()
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text("Mini-Games")
                }

            MissionsView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Missions")
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
    }
}

#Preview {
    ContentView()
}
