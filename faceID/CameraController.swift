//
//  CameraController.swift
//  faceID
//
//  Created by Davide on 21/07/2020.
//  Copyright © 2020 Davide. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Vision

class CameraController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()

    private var recognizer :Recognizer = Recognizer()
    private var faceBoundingBoxShape = CAShapeLayer()
    private var out_label : UILabel = UILabel()
    private var preview: UIImageView? = nil
    @IBOutlet weak var time_label: UILabel!
    
    private var to_crop :UIImage? = nil
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.time_label.isHidden = true
        
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            DispatchQueue.main.async {
                self.startRecognize()
            }
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                DispatchQueue.main.async {
                    if granted {
                        self.startRecognize()
                    } else {
                        self.showAlertButtonTapped()
                    }
                }
            })
        }
    }
    
        
    @IBAction func showAlertButtonTapped() {
        let alert = UIAlertController(title: "Camera Permission needed", message: "Go to settings -> faceID -> Camera -> enable", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "close", style: UIAlertAction.Style.default,handler: {(alert: UIAlertAction!) in self.presentingViewController?.dismiss(animated: true, completion: nil)}))
        self.present(alert, animated: true, completion: nil)
    }

    func startRecognize(){
        self.time_label.isHidden = false
        
        //top-left execution time label
        self.time_label.layer.backgroundColor = UIColor.link.cgColor
        self.time_label.layer.cornerRadius = 10.0

        //text: name + probability
        self.out_label.textAlignment = .center
        self.out_label.font =  UIFont.systemFont(ofSize: 20)
        self.out_label.textColor = .white
        self.out_label.numberOfLines = 1
        self.out_label.layer.cornerRadius = 10.0
        self.out_label.layer.masksToBounds = true
        
        //bounding box
        self.faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
        self.faceBoundingBoxShape.strokeColor = UIColor.link.cgColor
        self.faceBoundingBoxShape.lineWidth = 5
        
        //**************************** DEBUG ****************************
        //simula frame CVPixelBuffer a partire da immagini UIImage statiche
        /*
        let listimage = ["mn","neuer", "alex", "muller", "kim", "carletto"]
        for i in listimage {
            print("\n\n"+i)
            guard let image = UIImage(named:i) else { return }
            let imageView = UIImageView(image: image)
            view.addSubview(imageView)
            imageView.contentMode = .scaleAspectFit
            let scaledHeight = view.frame.width / image.size.width * image.size.height
            imageView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: scaledHeight)
            
            let cvimage : CVPixelBuffer = image.toCVPixelBuffer()!
            self.detectFace(in: cvimage)
        }*/
        //***************************************************************

        self.addCameraInput() //simulator crash
        self.showCameraFeed()
        self.getCameraFrames()
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }

    private func addCameraInput() {
        guard let device = AVCaptureDevice.default(for: .video) else {
               fatalError("No back camera device found, please make sure to run SimpleLaneDetection in an iOS device and not a simulator")
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.sessionPreset = .photo //best line ever
        self.captureSession.addInput(cameraInput)
    }
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
    }
    
    private func getCameraFrames() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }

    //metodo che riceve i frame della fotocamera per elaborarli
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        self.detectFace(in: frame)
    }
    
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation] {
                    if results.count == 0 {
                        self.clearDrawings()
                    }
                    else {
                        self.to_crop = UIImage.getUI(buffer: image)
                        self.handleFaceDetectionResults(results)
                    }
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .up, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        let viewWidth = self.view.frame.width
        let viewHeight = self.view.frame.height
        DispatchQueue.global(qos: .userInitiated).async {
            for face in observedFaces{
                let t_start = NSDate().timeIntervalSince1970
                
                let scaledHeight = viewWidth / self.to_crop!.size.width * self.to_crop!.size.height
                let x = viewWidth * face.boundingBox.origin.x
                let w = viewWidth * face.boundingBox.width
                let h = scaledHeight * face.boundingBox.height
                let y = scaledHeight * (1 - face.boundingBox.origin.y) - h
                let scaledRect = CGRect(x: x, y: y, width: w, height: h)

                guard let cropped = self.to_crop!.cropFace((self.to_crop?.cgImage)!, toRect: scaledRect, viewWidth: viewWidth, viewHeight: viewHeight) else {return}
                self.recognizer.recognize(image: cropped)
                
                let text = "\(self.recognizer.name) \(String(format: "%.2f", self.recognizer.probability))"
                print(text)

                let t_end = NSDate().timeIntervalSince1970
                self.drawBoundingBox(cropped, scaledRect, text, t_end - t_start, self.recognizer.probability)
            }
        }
    }
    
    private func clearDrawings() {
        DispatchQueue.main.async {
            self.faceBoundingBoxShape.removeFromSuperlayer()
            self.out_label.removeFromSuperview()
            //self.preview = nil
        }
    }
    
    private func drawBoundingBox(_ image: UIImage, _ rect : CGRect, _ text : String, _ time: Double, _ p: Double) {
        DispatchQueue.main.async {
            //rect
            self.faceBoundingBoxShape.path = UIBezierPath(roundedRect: rect, cornerRadius: 15.0).cgPath
            self.view.layer.addSublayer(self.faceBoundingBoxShape)

            //label: name + probability
            if p >= 0.40 {
                self.faceBoundingBoxShape.strokeColor = UIColor.link.cgColor
                self.out_label.backgroundColor = UIColor.link
            }
            else {
                self.faceBoundingBoxShape.strokeColor = UIColor.red.cgColor
                self.out_label.backgroundColor = UIColor.red
            }
            self.out_label.text = text
            self.out_label.sizeToFit()
            self.out_label.layer.frame = CGRect(x: 0, y: 0, width: self.out_label.frame.width + 10, height: 33)
            self.out_label.center.x = rect.origin.x + rect.width/2
            self.out_label.center.y = rect.maxY + 25
            self.view.addSubview(self.out_label)

            //preview on the bottom-left corner
            //self.preview = UIImageView(image: image)
            //self.preview!.center.y = self.view.bounds.maxY - 100
            //self.view.addSubview(self.preview!)
            
            //time on top-right corner
            self.time_label.text = String(format: "%.3f", time) + " s"
            self.view.addSubview(self.time_label)
        }
    }
    
    //**************************** DEBUG ****************************
    private func drawPoint(_ x: CGFloat, _ y: CGFloat){
        let dotPath = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 8, height: 8))
        let layer = CAShapeLayer()
        layer.path = dotPath.cgPath
        layer.strokeColor = UIColor.yellow.cgColor
        self.view.layer.addSublayer(layer)
    }
    //***************************************************************
}
