//
//  FlowView.swift
//  Flower Tamagochi
//
//  Created by Сергей Ларкин on 10/09/2025.
//

import SwiftUI

struct FlowMessage: View{
    var message: String
    var body: some View {
        ZStack{
            Image("Message")
                .resizable()
                .frame(width: 200, height: 100)
            Text(message)
                .font(.system(size: 20))
                .fontWeight(.bold)
                .offset(x: 0, y: -10)
        }
    }
}

#Preview {
    FlowMessage(message: "Я хочу пить!")
}
