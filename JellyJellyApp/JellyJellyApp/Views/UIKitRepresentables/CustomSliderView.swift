//
//  CustomSliderView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import UIKit

class CustomSlider: UISlider {
    override func awakeFromNib() {
        super.awakeFromNib()
        setupSlider()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSlider()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSlider()
    }
    
    private func setupSlider() {
        let thumbSize: CGFloat = 12
        let thumbImage = createThumbImage(size: thumbSize)
        
        setThumbImage(thumbImage, for: .normal)
        setThumbImage(thumbImage, for: .highlighted)
        
        minimumTrackTintColor = .white
        maximumTrackTintColor = .white.withAlphaComponent(0.3)
    }
    
    private func createThumbImage(size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.setStrokeColor(UIColor.black.withAlphaComponent(0.2).cgColor)
            context.cgContext.setLineWidth(0.5)
            
            context.cgContext.fillEllipse(in: rect)
            context.cgContext.strokeEllipse(in: rect)
        }
    }
    
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let thumbRect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        let smallerSize: CGFloat = 12
        return CGRect(
            x: thumbRect.midX - smallerSize/2,
            y: thumbRect.midY - smallerSize/2,
            width: smallerSize,
            height: smallerSize
        )
    }
}

struct CustomSliderView: UIViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self._value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }
    
    func makeUIView(context: Context) -> CustomSlider {
        let slider = CustomSlider()
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingBegan(_:)),
            for: .touchDown
        )
        
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingEnded(_:)),
            for: [.touchUpInside, .touchUpOutside]
        )
        
        return slider
    }
    
    func updateUIView(_ uiView: CustomSlider, context: Context) {
        uiView.value = Float(value)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CustomSliderView
        
        init(_ parent: CustomSliderView) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ slider: UISlider) {
            parent.value = Double(slider.value)
        }
        
        @objc func editingBegan(_ slider: UISlider) {
            parent.onEditingChanged(true)
        }
        
        @objc func editingEnded(_ slider: UISlider) {
            parent.onEditingChanged(false)
        }
    }
}
