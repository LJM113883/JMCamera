//
//  JMAVCaptureSession.swift
//  JMCamera
//
//  Created by Min Han on 2020/11/4.
//  Copyright © 2020 Min Han. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

// 1. 添加捕捉服务 Session
// 2. 添加 音频输入 视频输入
class JMAVCaptureSession: NSObject {
    // 设置单例 私有 初始化方法
    static public let shareInstance = JMAVCaptureSession()
    private override init() {}
    // 对象被销毁
    deinit {
        // 停止录制
        stopRuning()
        // 销毁监听
        NotificationCenter.default.removeObserver(self)
    }
    // 懒加载扑捉服务
    lazy private var session : AVCaptureSession = {
        let ses = AVCaptureSession()
        // 设置采样率
        ses.canSetSessionPreset(.hd1280x720)
        // 添加视频输入流
        if self.videoInput != nil{
            if ses.canAddInput(self.videoInput!) {
                ses.addInput(self.videoInput!)
            }
        }
        // 添加音频输入流
        if self.audioInput != nil {
            if ses.canAddInput(self.audioInput!) {
                ses.addInput(self.audioInput!)
            }
        }
        // 添加画面输出
        if ses.canAddOutput(self.videoOutput){
            ses.addOutput(self.videoOutput)
        }
        // 添加音频输出
        if ses.canAddOutput(self.audioOutput){
            ses.addOutput(self.audioOutput)
        }
        let connnect = self.videoOutput.connection(with: .video)
        // 前置摄像头采集的是翻转，设置为镜像把画面翻转回来
        if(self.devicePosition == .front && (connnect?.isVideoMirroringSupported ?? false)){
            connnect?.isVideoMirrored = true
        }
//        // 设置视频方向
        connnect?.videoOrientation = .portrait
        return ses
    }()
    // 视频输入设备
    lazy private var videoInput : AVCaptureDeviceInput? = {
        // 默认获取后置摄像头
        let device = self.cameraVideoInput(position: .front)
        return device
    }()
    // 音频输入设备
    lazy private var audioInput : AVCaptureDeviceInput? = {
        let device = AVCaptureDevice.default(for: .audio)
        guard device != nil else {
            print("获取不到音频设备")
            return nil
        }
        let audio =  try? AVCaptureDeviceInput(device: device!)
        return audio
    }()
    // 视频输出
    lazy private var videoOutput : AVCaptureVideoDataOutput = {
        let videoOut = AVCaptureVideoDataOutput()
        videoOut.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        return videoOut
    }()
    // 音频输出
    lazy private var audioOutput : AVCaptureAudioDataOutput = {
        let audioOut = AVCaptureAudioDataOutput()
        audioOut.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        return audioOut
    }()
    // 显示 画面 layer
    lazy private var previewLayer : AVCaptureVideoPreviewLayer = {
        let preLayer = AVCaptureVideoPreviewLayer(session: self.session)
        preLayer.videoGravity = .resizeAspect
        return preLayer
    }()
    
    // 外部api
    open var preView : UIView? {
        // 监听
        willSet{
            guard newValue != nil else {
                self.previewLayer.removeFromSuperlayer()
                return
            }
            self.previewLayer.frame = newValue!.bounds
            newValue?.layer.addSublayer(self.previewLayer)
        }
    }
    // 采集状态 readOnly
    var isRunning : Bool {
        get{
            return self.session.isRunning
        }
    }
    // 获取采集摄像头位置 readOnly
    var devicePosition : AVCaptureDevice.Position {
        get{
            guard self.videoInput != nil else {
                // 未定义
                return .unspecified
            }
            if self.videoInput!.device.position == .unspecified {
                return .back
            }
            return self.videoInput!.device.position
        }
    }
}

extension  JMAVCaptureSession {
    // 获取摄像头
    private func cameraDeviceForPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.2, *) {
            // 10.2 之后的新方法
            let discover = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera,.builtInTelephotoCamera,.builtInWideAngleCamera], mediaType: .video, position: position)
            // 遍历出 device
            for device in discover.devices {
                if device.position == position {
                    return device
                }
            }
        }else{
            // 获取摄像头
            let devices = AVCaptureDevice.devices(for: .video)
            //
            for device in devices {
                if (device.position == position) {
                    return device
                }
            }
        }
        return nil
    }
    // 获取画面输入
    private func cameraVideoInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        let device = cameraDeviceForPosition(position: position)
        //
        guard device != nil else{
            print("获取不到摄像头")
            return nil
        }
        let video = try? AVCaptureDeviceInput(device: device!)
        return video
    }
    // 开始采集
    func startRuning()  {
        if !self.session.isRunning {
            self.session.startRunning()
        }
    }
    // 停止采集
    func stopRuning() {
        if self.session.isRunning {
            self.session.stopRunning()
        }
    }
    // 切换摄像头
    func switchCamera(position: AVCaptureDevice.Position) {
        // 如果当前和切换的相同 return
        guard position != .unspecified && position != self.devicePosition else{
            print("采集摄像头位置不确定 或则 与当前摄像头位置相同")
            return
        }
        let newDeviceInput = cameraVideoInput(position: position)
        guard newDeviceInput != nil else {
            print("新采集摄像头 获取失败")
            return
        }
        // 1. 开启 Session 的配置服务
        session.beginConfiguration()
        // 2. 移除当前画面采集，并重新配置采集
        session.removeInput(self.videoInput!)
        if session.canAddInput(newDeviceInput!) {
            self.videoInput = newDeviceInput
            session.addInput(newDeviceInput!)
           
        }else{
            session.addInput(self.videoInput!)
        }
        // 重新连接
        let connect = self.videoOutput.connection(with: .video)
        if self.devicePosition == .front && (connect?.isVideoMirroringSupported ?? false) {
            connect?.isVideoMirrored = true
        }
        connect?.videoOrientation = .portrait
        session.commitConfiguration()
    }
}
// 音视频数据输出代理
extension JMAVCaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print(connection,sampleBuffer, output)
    }
}
protocol JMAVCaptureSessionDelegate {
    
}
