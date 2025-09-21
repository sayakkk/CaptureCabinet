//
//  FullScreenImageView.swift
//  CaptureCabinet
//
//  Created by saya lee on 9/21/25.
//

import SwiftUI
import Photos

struct FullScreenImageView: View {
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    let screenshots: [Screenshot]
    
    @State private var dragOffset: CGSize = .zero
    @State private var dragScale: CGFloat = 1.0
    @State private var isDragging = false
    
    init(isPresented: Binding<Bool>, currentIndex: Int, screenshots: [Screenshot]) {
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: currentIndex)
        self.screenshots = screenshots
    }
    
    var body: some View {
        ZStack {
            // 배경
            Color.black.ignoresSafeArea()
            
            if !screenshots.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(screenshots.indices, id: \.self) { index in
                        ScreenshotFullView(
                            screenshot: screenshots[index],
                            dragOffset: $dragOffset,
                            dragScale: $dragScale,
                            isDragging: $isDragging,
                            onClose: { isPresented = false }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .offset(dragOffset)
                .scaleEffect(dragScale)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            
                            // 아래로 드래그할 때만 반응
                            if value.translation.height > 0 {
                                dragOffset = value.translation
                                let progress = min(value.translation.height / 200, 1.0)
                                dragScale = 1.0 - (progress * 0.3)
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // 아래로 충분히 드래그했으면 닫기, 100에서 50으로
                            if value.translation.height > 50 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isPresented = false
                                }
                            } else {
                                // 원래 위치로 돌아가기
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                    dragScale = 1.0
                                }
                            }
                        }
                )
            }
            
            // 뒤로 버튼
            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            // 전체화면 진입 시 애니메이션
            withAnimation(.easeInOut(duration: 0.3)) {
                dragScale = 1.0
            }
        }
    }
}

struct ScreenshotFullView: View {
    let screenshot: Screenshot
    @Binding var dragOffset: CGSize
    @Binding var dragScale: CGFloat
    @Binding var isDragging: Bool
    let onClose: () -> Void
    
    @State private var image: UIImage?
    @State private var asset: PHAsset?
    @State private var horizontalDragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .offset(x: horizontalDragOffset)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .onAppear {
            loadAssetAndImage()
        }
    }
    
    private func loadAssetAndImage() {
        guard let assetID = screenshot.phAssetID else { return }
        
        // PHAsset 찾기
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let phAsset = fetchResult.firstObject else { return }
        
        asset = phAsset
        
        // 전체 화면용 고해상도 이미지 로드
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(
            width: screenSize.width * UIScreen.main.scale,
            height: screenSize.height * UIScreen.main.scale
        )
        
        manager.requestImage(
            for: phAsset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}

#Preview {
    FullScreenImageView(
        isPresented: .constant(true),
        currentIndex: 0,
        screenshots: []
    )
}
