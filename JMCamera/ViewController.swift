//
//  ViewController.swift
//  JMCamera
//
//  Created by Min Han on 2020/11/4.
//  Copyright © 2020 Min Han. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    let preView = UIImageView(frame: UIScreen.main.bounds)
    let session = JMAVCaptureSession.shareInstance
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(preView)
        session.preView = preView
        session.startRuning()
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (session.devicePosition == .front){
            session.switchCamera(position: .back)
        }else if(session.devicePosition == .back){
            session.switchCamera(position: .front)
        }
    }
}

