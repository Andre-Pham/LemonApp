//
//  Environment.swift
//  Lemon
//
//  Created by Andre Pham on 30/6/2023.
//

import Foundation
import UIKit

class Environment {
    
    public static let inst = Environment()
    
    private var safeAreaInsets: UIEdgeInsets? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        return windowScene.windows.first?.safeAreaInsets
    }
    
    public var topSafeAreaHeight: CGFloat {
        return self.safeAreaInsets?.top ?? 0.0
    }
    
    public var bottomSafeAreaHeight: CGFloat {
        return self.safeAreaInsets?.bottom ?? 0.0
    }
    
    private init() { }
    
}
