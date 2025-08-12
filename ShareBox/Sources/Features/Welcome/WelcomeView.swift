//
//  WelcomeView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/08/2025.
//

import SwiftUI
import AuthenticationServices
import UserNotifications

struct WelcomeView<C: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State var state = WelcomeViewModel()

    @ViewBuilder var content: () -> C
    
    var body: some View {
        ZStack {
            if state.authenticated {
                content()
            }
            VStack {
                Spacer()
                Text("Welcome")
                    .foregroundStyle(.primary)
                    .font(.system(size: 36, weight: .bold))
                    .fontDesign(.serif)
                Text("Sign in to ShareBox to get started sharing files easy and quickly.")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
                SignInWithAppleButton(.signUp, onRequest: { request in
                    request.requestedScopes = [.email, .fullName]
                }, onCompletion: state.onSignIn)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(width: 180)
                .scaleEffect(1.2)
            }
            .padding(24)
            .background(
                Image("lines")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea(.all)
            )
            .opacity(state.authenticated ? 0 : 1)
            .scaleEffect(state.authenticated ? 1.1 : 1)
            .allowsHitTesting(!state.authenticated)
        }
    }
}

#Preview {
    WelcomeView {
        Text("Authenticated content")
    }
        .frame(width: 425, height: 600)
}
