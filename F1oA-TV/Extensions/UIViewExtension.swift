//
//  UIViewExtension.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit
import SkeletonView

extension UIView {
    func dropShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowRadius = 3
    }
    
    func backgroundShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 7
    }
    
    func straightShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 3
    }
    
    /*func tableItemShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 7
    }*/
    
    func tableItemShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowRadius = 4
    }
    
    func removeShadow() {
        layer.shadowColor = UIColor.clear.cgColor
        layer.shadowOpacity = 0
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 0
    }
    
    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }
    
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
    
    func showSkeletonAnimation() {
        self.isSkeletonable = true
        self.showAnimatedGradientSkeleton()
    }
    
    func hideSkeletonAnimation() {
        self.hideSkeleton(transition: .crossDissolve(0.25))
    }
    
    func gradientBackground(colors : [UIColor]) {
        // Turn the colors into CGColors
        let cgcolors = colors.map { $0.cgColor }
        
        let size = CGSize(width: self.frame.width, height: self.frame.height)
        // Begin the graphics context
        UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
        
        // If no context was retrieved, then it failed
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // From now on, the context gets ended if any return happens
        defer { UIGraphicsEndImageContext() }
        
        // Create the Coregraphics gradient
        var locations : [CGFloat] = [0.0, 1.0]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgcolors as NSArray as CFArray, locations: &locations) else { return }
        
        // Draw the gradient
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: [])
        
        // Generate the image (the defer takes care of closing the context)
        let patternImage = UIGraphicsGetImageFromCurrentImageContext()
        
        self.backgroundColor = UIColor(patternImage: patternImage!)
    }
}

@IBDesignable
class DesignableView: UIView {
    @IBInspectable var shadowColor: UIColor = UIColor.clear {
        didSet {
            layer.shadowColor = shadowColor.cgColor
        }
    }

    @IBInspectable var shadowRadius: CGFloat = 0 {
        didSet {
            layer.shadowRadius = shadowRadius
        }
    }

    @IBInspectable var shadowOpacity: CGFloat = 0 {
        didSet {
            layer.shadowOpacity = Float(shadowOpacity)
        }
    }

    @IBInspectable var shadowOffsetY: CGFloat = 0 {
        didSet {
            layer.shadowOffset.height = shadowOffsetY
        }
    }
}
