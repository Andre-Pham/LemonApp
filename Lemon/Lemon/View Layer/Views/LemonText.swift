//
//  LemonText.swift
//  Lemon
//
//  Created by Andre Pham on 14/6/2023.
//

import Foundation

import Foundation
import UIKit

class LemonText: LemonUIView {
    
    private let label = UILabel()
    public var view: UIView {
        return self.label
    }
    
    init(text: String? = nil, font: UIFont? = UIFont.boldSystemFont(ofSize: 13.0)) {
        self.setText(to: text)
        self.setFont(to: font)
    }
    
    @discardableResult
    func setText(to text: String?) -> Self {
        self.label.text = text
        return self
    }
    
    @discardableResult
    func setFont(to font: UIFont?) -> Self {
        self.label.font = font
        return self
    }
    
    @discardableResult
    func setSize(to size: CGFloat) -> Self {
        self.label.font = self.label.font.withSize(size)
        return self
    }
    
}
