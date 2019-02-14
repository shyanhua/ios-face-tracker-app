//
//  ViewController.swift
//  FaceDetect
//
//  Created by Shyan Hua on 04/01/2019.
//  Copyright © 2019 Shyan Hua. All rights reserved.
//

import AVFoundation
import GoogleMobileVision

@available(iOS 10.0, *)
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate
{

    var faceId : UInt = 0
    
    //flag
    var flagFrontFace = false, flagSmile = false, flagFaceRight = false, flagFaceLeft = false, flagFaceId = false, flagCapture = false

    //Video objects
    var previewLayer: AVCaptureVideoPreviewLayer?
    var session: AVCaptureSession?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    
    //Selfie objects
    var stillImageOutput = AVCapturePhotoOutput()

    //detector
    var faceDetector: GMVDetector?
    
    //UI elements
    @IBOutlet weak var overlay: UIView!
    @IBOutlet weak var buttonSwitch: UISwitch!
    @IBOutlet weak var placeholder: UIView!
    
    //initWithCoder
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Set up default camera settings.
        session = AVCaptureSession()
        session?.sessionPreset = AVCaptureSession.Preset.medium
        buttonSwitch.isOn = true
        updateCameraSelection()
        // Setup video processing pipeline.
        setupVideoProcessing()
        // Setup camera preview.
        setupCameraPreview()
        // Initialize the face detector.
        self.faceDetector = GMVDetector(ofType: GMVDetectorTypeFace, options: [GMVDetectorFaceLandmarkType: GMVDetectorFaceLandmark.all.rawValue,
                                                                               GMVDetectorFaceClassificationType: GMVDetectorFaceClassification.all.rawValue,
                                                                               GMVDetectorFaceMinSize: 0.3,
                                                                               GMVDetectorFaceTrackingEnabled: true])
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = self.view.layer.bounds
        previewLayer?.position = CGPoint(x: (previewLayer?.frame.midX)!, y: (previewLayer?.frame.midY)!)
    }
    
//    override func didReceiveMemoryWarning()
//    {
//        cleanUpCaptureSession()
//        super.didReceiveMemoryWarning()
//    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        session?.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        session?.stopRunning()
    }
    
    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval)
    {
            // Camera rotation needs to be manually set when rotation changes.
            if previewLayer != nil
            {
                if toInterfaceOrientation == UIInterfaceOrientation.portrait
                {
                    previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                }
                else if toInterfaceOrientation == UIInterfaceOrientation.portraitUpsideDown
                {
                    previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
                }
                else if toInterfaceOrientation == UIInterfaceOrientation.landscapeLeft
                {
                    previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                }
                else if toInterfaceOrientation == UIInterfaceOrientation.landscapeRight
                {
                    previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
                }
            }
    }

    // pragma mark - Helper methods
    func deviceOrientationFromInterfaceOrientation() -> UIDeviceOrientation
    {
            var defaultOrientation: UIDeviceOrientation = UIDeviceOrientation.portrait
            switch UIApplication.shared.statusBarOrientation
            {
                case UIInterfaceOrientation.landscapeLeft :
                        defaultOrientation = UIDeviceOrientation.landscapeRight
                        break
                case UIInterfaceOrientation.landscapeRight :
                        defaultOrientation = UIDeviceOrientation.landscapeLeft
                        break
                case UIInterfaceOrientation.portraitUpsideDown :
                        defaultOrientation = UIDeviceOrientation.portraitUpsideDown
                        break
                case UIInterfaceOrientation.portrait :
                        break
                default:
                        defaultOrientation = UIDeviceOrientation.portrait
                        break
            }
            return defaultOrientation
    }
    
    //pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        let devicePosition: AVCaptureDevice.Position = buttonSwitch.isOn ? .front : .back
//         Establish the image orientation.
        let deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
        let orientation: GMVImageOrientation = GMVUtility.imageOrientation(from: deviceOrientation, with: devicePosition, defaultDeviceOrientation: deviceOrientationFromInterfaceOrientation())
        let options = [GMVDetectorImageOrientation: orientation.rawValue]
//                 Detect features using GMVDetector.
        let faces : [GMVFaceFeature] = faceDetector?.features(in: sampleBuffer, options: options) as! [GMVFaceFeature]

        print(String(format: "Detected %lu face(s).", faces.count))
        
        // Bounce back to the main thread to update the UI
//        DispatchQueue.main.sync
//            {
//                for featureview: UIView? in self.overlay.subviews
//                {
//                    featureview?.removeFromSuperview()
//                }
//        }

        for face in faces
        {
            // Tracking id.
            if face.hasTrackingID
            {
                //get faceId
                if flagFaceId == false
                {
                    faceId = face.trackingID
                    flagFaceId = true
                }
                
                //reset flag if faceId changed
                if flagFaceId == true && face.trackingID > faceId
                {
                    resetFlag()
                }
            }
        
        
            let faceY = face.headEulerAngleY
            //detect front face
            if flagFrontFace == false
            {
                if CGFloat(faceY) > -12 && CGFloat(faceY) < 12
                {
                    let myAlert = UIAlertController(title:"Face", message:"Front face detected, please show your left face.", preferredStyle: .alert)
                    let okAction = UIAlertAction(title:"Ok", style: .default)
                    myAlert.addAction(okAction)
                    
                    if self.presentedViewController == nil
                    {
                        self.present(myAlert, animated: true,completion: nil)
                    }
                    else
                    {
                        self.dismiss(animated: false, completion: nil)
                        self.present(myAlert, animated: true,completion: nil)
                    }
                    sleep(2)
                    flagFrontFace = true
                    return
                }
            }
            
            //front face detected, then detect left face and detect right face
            if flagFrontFace == true
            {
                //detect left face
                if flagFaceLeft == false
                {
                    if CGFloat(faceY) > 36
                    {
                        let myAlert = UIAlertController(title:"Face", message:"Left face detected, please show your right face.", preferredStyle: .alert)
                        let okAction = UIAlertAction(title:"Ok", style: .default)
                        myAlert.addAction(okAction)
                        
                        if self.presentedViewController == nil
                        {
                            self.present(myAlert, animated: true,completion: nil)
                        }
                        else
                        {
                            self.dismiss(animated: false, completion: nil)
                            self.present(myAlert, animated: true,completion: nil)
                        }
                        sleep(2)
                        flagFaceLeft = true
                        return
                    }
                }
                
                //detect right face
                if flagFaceLeft == true
                {
                    if flagFaceRight == false
                    {
                        if CGFloat(faceY) < -36
                        {
                            let myAlert = UIAlertController(title:"Face", message:"Right face detected, please smile to the take a selfie.", preferredStyle: .alert)
                            let okAction = UIAlertAction(title:"Ok", style: .default)
                            myAlert.addAction(okAction)
                            
                            if self.presentedViewController == nil
                            {
                                self.present(myAlert, animated: true,completion: nil)
                            }
                            else
                            {
                                self.dismiss(animated: false, completion: nil)
                                self.present(myAlert, animated: true,completion: nil)
                            }
                            sleep(2)
                            flagFaceRight = true
                            return
                        }
                    }
                }
            }
            
            //detect smile
            if flagFaceLeft == true && flagFaceRight == true
            {
                if flagSmile == false
                {
                    //checking for mouth smiling
                    if face.hasSmilingProbability
                    {
                        if CGFloat(face.smilingProbability) > 0.6
                        {
                            let myAlert = UIAlertController(title:"Face", message:"Captured !", preferredStyle: .alert)
                            let okAction = UIAlertAction(title:"Ok", style: .default)
                            myAlert.addAction(okAction)
                            if self.presentedViewController == nil
                            {
                                self.present(myAlert, animated: true,completion: nil)
                            }
                            else
                            {
                                self.dismiss(animated: false, completion: nil)
                                self.present(myAlert, animated: true,completion: nil)
                            }
                            sleep(2)
                            flagSmile = true
                            return
                        }
                    }
                }
            }
            
            //show camera
            if(flagSmile == true && flagCapture == false)
            {
                //TODO : camera take faceVerified()
                faceVerified()
                flagCapture = true
                return
            }

        }
    }
    
    //pragma mark - Camera setup
    func cleanUpVideoProcessing() -> Void
    {
        if videoDataOutput != nil
        {
            session?.removeOutput(videoDataOutput!)
        }
        videoDataOutput = nil
    }
    
//    func cleanUpCaptureSession() -> Void
//    {
//        session?.stopRunning()
//        cleanUpVideoProcessing()
//        session = nil
//        previewLayer?.removeFromSuperlayer()
//    }
    
    func setupVideoProcessing() -> Void
    {
        videoDataOutput = AVCaptureVideoDataOutput()
        let rgbOutputSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput?.videoSettings = rgbOutputSettings

        if !(session?.canAddOutput(videoDataOutput!))!
        {
            cleanUpVideoProcessing()
            print("Failed to setup video output")
            return
        }
        
        if !(session?.canAddOutput(stillImageOutput))!
        {
            cleanUpVideoProcessing()
            print("Failed to setup video output")
            return
        }
        
        videoDataOutput?.alwaysDiscardsLateVideoFrames = true
        videoDataOutput?.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        session?.addOutput(videoDataOutput!)
        session?.addOutput(stillImageOutput)
    }
    
    func setupCameraPreview() -> Void
    {
        previewLayer = AVCaptureVideoPreviewLayer(session: session!)
        previewLayer?.backgroundColor = UIColor.white.cgColor
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
        let rootLayer : CALayer = placeholder.layer
        rootLayer.masksToBounds = true
        previewLayer?.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer!)
    }
    
    func updateCameraSelection() -> Void
    {
        session?.beginConfiguration()
        
        // Remove old inputs
        let oldInputs = session?.inputs
        
        for oldInput: AVCaptureInput in oldInputs!
        {
            session?.removeInput(oldInput)
        }
        
        let desiredPosition: AVCaptureDevice.Position = buttonSwitch.isOn ? .front : .back
        let input: AVCaptureDeviceInput? = cameraForPosition(for: desiredPosition)
        if input == nil
        {
            // Failed, restore old inputs
            for oldInput: AVCaptureInput? in oldInputs!
            {
                if let oldInput = oldInput
                {
                    session?.addInput(oldInput)
                }
            }
        }
        else
        {
            // Succeeded, set input and update connection states
            if let input = input
            {
                session?.addInput(input)
            }
        }
        session?.commitConfiguration()
    }
    
    func cameraForPosition(for desiredPosition: AVCaptureDevice.Position) -> AVCaptureDeviceInput?
    {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)

        for device in devices.devices
        {
            if device.position == desiredPosition
            {
                let input = try? AVCaptureDeviceInput(device: device)
                if (session?.canAddInput(input!))!
                {
                    return input
                }
            }
        }
        
        return nil
    }

    @IBAction func buttonSwitch(_ sender: Any)
    {
        updateCameraSelection()
    }
    
    //pragma mark - private method
    func resetFlag() -> Void
    {
        flagSmile = false
        flagFrontFace = false
        flagFaceLeft = false
        flagFaceRight = false
        flagFaceId = false
    }
    
    func faceVerified() -> Void
    {
        self.performSelector(onMainThread: #selector(capturePhoto), with: nil, waitUntilDone: false)
//        self.performSelector(inBackground: #selector(capturePhoto), with: nil)
    }
    
    @objc func capturePhoto()
    {
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160]
        settings.previewPhotoFormat = previewFormat
        
        self.stillImageOutput.isHighResolutionCaptureEnabled = true
        self.stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?)
    {
        if let error = error
        {
            print(error.localizedDescription)
        }
        run(after: 1)
        {
            let imageData = photo.fileDataRepresentation()
            UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData!)!, nil, nil, nil)
        }
    }
    
    func run(after seconds: Int, completion: @escaping () -> Void)
    {
        let deadline = DispatchTime.now() + .seconds(seconds)
        
        DispatchQueue.main.asyncAfter(deadline: deadline)
        {
            completion()
        }
    }
  
}

