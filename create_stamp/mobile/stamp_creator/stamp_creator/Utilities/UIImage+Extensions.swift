//
//  UIImage+Extensions.swift
//  stamp_creator
//
//  UIImageの拡張機能
//

import UIKit
import ImageIO

extension UIImage {
    func fixedOrientation() -> UIImage? {
        if imageOrientation == .up {
            return self
        }
        
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        let width: CGFloat
        let height: CGFloat
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            width = CGFloat(cgImage.height)
            height = CGFloat(cgImage.width)
        default:
            width = CGFloat(cgImage.width)
            height = CGFloat(cgImage.height)
        }
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: UIGraphicsImageRendererFormat.default())
        let correctedImage = renderer.image { context in
            self.draw(in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        }
        
        return correctedImage
    }
}
