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

    private var content: some View {
        HStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        ItemPreview(path: item.absolute, completed: state.completedPaths.contains(item.absolute), error: state.failedPaths[item.absolute])
                    }
                }
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            VStack {
                ProgressView(progress: state.uploadProgress)
            }
            // Extra padding for fades
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 90)
        .onHover { isOver in
            if state.hidden { return }
            withAnimation(.spring(duration: 0.3)) {
                state.notchPercentage = isOver ? 1 : 0
            }
        }
        .offset(x: state.notchPercentage == 0 ? -77 : 0)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            NotchShape(notchPercentage: state.notchPercentage)
                .fill(.black)
                .animation(.spring(duration: 0.3), value: state.notchPercentage)
            
            // Content
            content
            // Overlay gradient for better scrolling transition
            VStack(alignment: .center) {
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 10)
                Spacer()
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 10)
            }
            .padding(.vertical, 90)
            .padding(.horizontal, 10)
            .offset(x: state.notchPercentage == 0 ? -77 : 0)
            .allowsHitTesting(false)
        }
        .offset(x: state.hidden ? -23 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await state.handleAppear(items)
        }
    }
}

#Preview {
    UploadView(items: [])
        .frame(width: 100, height: 500)
}
