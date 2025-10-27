//
//  ImageViewerView.swift
//  MessageAI
//
//  Full-screen image viewer with zoom and pan gestures
//

import SwiftUI

struct ImageViewerView: View {
    let imageURL: String
    let caption: String?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else if loadError {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Failed to load image")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button("Retry") {
                        loadImage()
                    }
                    .foregroundColor(.blue)
                }
            } else {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 0.5), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale < 1.0 {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    },
                                
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        
                                        // Only allow dragging if image is zoomed
                                        if scale > 1.0 {
                                            offset = newOffset
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .onAppear {
                            isLoading = false
                        }
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            
            // Caption overlay
            if let caption = caption, !caption.isEmpty {
                VStack {
                    Spacer()
                    
                    Text(caption)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        isLoading = true
        loadError = false
        
        // The AsyncImage will handle the actual loading
        // This is just for initial state management
    }
}

// MARK: - Preview
struct ImageViewerView_Previews: PreviewProvider {
    static var previews: some View {
        ImageViewerView(
            imageURL: "https://example.com/image.jpg",
            caption: "Sample image caption"
        )
    }
}
