//
//  LemonSwitch.swift
//  Lemon
//
//  Created by Andre Pham on 30/6/2023.
//

import Foundation
import UIKit

class LemonSwitch: LemonUIView, LemonViewPublisher {
    
    var subscribers = [WeakLemonViewObserver]()
    
    private let switchView = UISwitch()
    private var onFlick: ((_ isOn: Bool) -> Void)? = nil
    
    public var isOn: Bool {
        return self.switchView.isOn
    }
    public var view: UIView {
        return self.switchView
    }
    
    override init() {
        super.init()
        self.switchView.addTarget(self, action: #selector(self.switchValueChanged(_:)), for: .valueChanged)
    }
    
    @discardableResult
    func setOnFlick(_ callback: ((_ isOn: Bool) -> Void)?) -> Self {
        self.onFlick = callback
        return self
    }
    
    @objc func switchValueChanged(_ sender: UISwitch) {
        self.onFlick?(self.isOn)
        self.publish(self)
   }
    
}
