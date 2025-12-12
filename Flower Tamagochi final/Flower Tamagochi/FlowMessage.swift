//
//  FlowMessage.swift
//  Flower Tamagochi
//
//  Created by Сергей Ларкин on 10/09/2025.
//

import SwiftUI

// MARK: - FlowMessage
struct FlowMessage: View {
    // MARK: Properties
    let message: String

    var body: some View {
        ZStack(alignment: .center) {
            Image("Message")
                .resizable()
                .frame(width: 200, height: 100)

            Text(message)
                .font(.system(size: 20))
                .fontWeight(.bold)
                .offset(y: -10)
        }
    }
}

#Preview {
    FlowMessage(message: "Я хочу пить!")
}
