//
//  SubscribeSignInView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI

struct SubscribeSignInView: View {
    @Binding var pageSelection: Int
    @Environment(User.self) var user

    var body: some View {
        SignInPage(
            user: user,
            cancelText: "Back",
            onCancel: {
                self.pageSelection -= 1
            },
            onContinue: {
                self.pageSelection += 1
            }
        )
    }
}

#Preview {
    SubscribeSignInView(pageSelection: .constant(0))
}
