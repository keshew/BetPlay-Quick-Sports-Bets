import SwiftUI

struct MiniGamesHubView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Guess the Score", destination: GuessTheScoreView())
                NavigationLink("Throw the Ball", destination: ThrowBallView())
            }
            .navigationTitle("Mini-Games")
        }
    }
}

#Preview {
    MiniGamesHubView()
}


