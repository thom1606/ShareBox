//
//  OnboardingSignInView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct OnboardingSignInView: View {
    @Binding var pageSelection: Int
    @Environment(User.self) var user

    @State private var isLoading: Bool = false
    @State private var approvedTerms: Bool = false

    var body: some View {
        SignInPage(onCancel: {
            self.pageSelection += 3
        }, onContinue: {
            self.pageSelection += 1
        })
    }
}
