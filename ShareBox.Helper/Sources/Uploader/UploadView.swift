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

    private var showSomeOverlay: Bool {
        state.showCompleteOverlay || state.showFailedOverlay
    }
    
    private var content: some View {
        ZStack {
            HStack(spacing: 10) {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(state.items, id: \.self) { item in
                            ItemPreview(
                                state: state,
                                item: item,
                                completed: state.completedPaths.contains(item.absolute)
                            )
                        }
                    }
                    // Extra padding for fades
                    .padding(.vertical, 10)
                }
                .frame(maxWidth: .infinity)
                if state.showProgressbar {
                    VStack {
                        ProgressView(progress: state.uploadProgress)
                    }
                    // Extra padding for fades
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 90)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            NotchShape(notchPercentage: state.notchPercentage)
                .fill(.black)
                .animation(.spring(duration: 0.3), value: state.notchPercentage)
            
            ZStack(alignment: .topLeading) {
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
                .allowsHitTesting(false)

                // Close Button
                Button(action: state.hideWindow, label: {
                    Image(systemName: "multiply.circle")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                })
                .buttonStyle(.plain)
                .opacity(state.showClose ? 1 : 0)
                .scaleEffect(state.showClose ? 1 : 0.4)
                .animation(.bouncy, value: state.showClose)
                .allowsHitTesting(state.showClose)
                .offset(x: 10, y: 65)
                .zIndex(9)
                
                // Complete Overlay
                ZStack(alignment: .topLeading) {
                    // To make sure the close button is hidden, we add a small rectangle on the same place :)
                    Rectangle()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.black)
                        .offset(x: 10, y: 65)
                    // Oerlay the rest of the content with the same offsets and paddings
                    ZStack(alignment: .topLeading) {
                        Image(systemName: "checkmark.seal")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .scaleEffect(state.showCompleteOverlay ? 1 : 0.3)
                            .rotationEffect(state.showCompleteOverlay ? .degrees(0) : .degrees(-180))
                            .opacity(state.showCompleteOverlay ? 1 : 0)
                            .animation(.bouncy, value: state.showCompleteOverlay)
                        
                        Image(systemName: "xmark.seal")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.red)
                            .frame(width: 30, height: 30)
                            .scaleEffect(state.showFailedOverlay ? 1 : 0.3)
                            .rotationEffect(state.showFailedOverlay ? .degrees(0) : .degrees(-180))
                            .opacity(state.showFailedOverlay ? 1 : 0)
                            .animation(.bouncy, value: state.showFailedOverlay)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .padding(.vertical, 90)
                    .padding(.horizontal, 10)
                }
                .opacity(showSomeOverlay ? 1 : 0)
                .animation(.spring(duration: 0.3), value: showSomeOverlay)
                .allowsHitTesting(showSomeOverlay)
                .zIndex(10)
            }
            .onHover { isOver in
                if state.hidden { return }
                withAnimation(.spring(duration: 0.3)) {
                    state.notchPercentage = isOver ? 1 : 0
                }
            }
            .offset(x: state.notchPercentage == 0 ? -80 : 0)
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
