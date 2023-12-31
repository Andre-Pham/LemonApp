//
//  JointPosition.swift
//  Lemon
//
//  Created by Andre Pham on 7/7/2023.
//

import Foundation
import UIKit
import Vision

class JointPosition {
    
    public let name: String
    public var position: CGPoint? = nil
    public var confidence: Float? = nil
    
    init(name: String) {
        self.name = name
    }
    
    func getDenormalisedPosition(for view: UIView) -> CGPoint? {
        return self.getDenormalisedPosition(viewWidth: view.bounds.width, viewHeight: view.bounds.height)
    }
    
    func getDenormalisedPosition(viewWidth: Double, viewHeight: Double) -> CGPoint? {
        if self.position == nil { return nil }
        return VNImagePointForNormalizedPoint(
            CGPoint(
                x: self.position!.x,
                y: 1 - self.position!.y
            ),
            Int(viewWidth),
            Int(viewHeight)
        )
    }
    
}
