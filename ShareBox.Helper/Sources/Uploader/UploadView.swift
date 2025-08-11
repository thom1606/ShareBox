//
//  UploadView.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI

struct UploadView: View {
    let items: [FilePath]

    @State private var state = UploadViewModel()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            NotchShape(notchPercentage: state.notchPercentage)
                .fill(.black)
                .animation(.spring(duration: 0.3), value: state.notchPercentage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    UploadView(items: [])
        .frame(width: 100, height: 500)
}
