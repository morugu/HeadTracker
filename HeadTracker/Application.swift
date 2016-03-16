import Cocoa
import AVFoundation

class Application : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let STATE_FRONTAL:UInt32 = 0x01 << 0;
    static let STATE_PROFILE:UInt32 = 0x01 << 1;
    
    enum Events {
        case None
        case Front
        case Profile
    }
    
    // camera sessions
    var videoSession:AVCaptureSession!
    var videoDevice:AVCaptureDevice!
    var videoInput:AVCaptureDeviceInput!
    var videoOutput:AVCaptureVideoDataOutput!
    var recognizer:Recognizer!
    
    var captureCounter:UInt64 = 0
    var stateProfileConfirmation = 0
    var state:UInt32 = 0
    
    func run() {
        self.recognizer = Recognizer()
        
        if self.initializeVideoCaptureSession() == false {
            return
        }
        
        self.videoSession.startRunning()
    }
    
    func initializeVideoCaptureSession() -> Bool {
        self.videoSession = AVCaptureSession()
        
        self.videoSession.beginConfiguration()
        self.videoSession.sessionPreset = AVCaptureSessionPresetLow
        
        if self.initializeVideoInput() == false {
            log.severe("initializing video input failed")
            return false
        }
        if self.initializeVideoOutput() == false {
            log.severe("initializing video output failed")
            return false
        }
        
        self.videoSession.commitConfiguration()
        
        return true
    }
    
    func initializeVideoInput() -> Bool {
        log.debug("initializing video input session...")
        
        log.debug("listing video devices...")
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in devices {
            let device = device as! AVCaptureDevice
            if device.connected == false {
                continue
            }
            
            log.debug("video deivce found: \(device.uniqueID)")
            self.videoDevice = device
        }
        if self.videoDevice == nil {
            log.severe("no video device found, giving up")
            return false
        }
        log.debug("video deivce selected: \(self.videoDevice.uniqueID)")
        
        do {
            self.videoInput = try AVCaptureDeviceInput(device: self.videoDevice)
        } catch _ {
            log.severe("failed to select device input")
            return false
        }

        if self.videoSession.canAddInput(self.videoInput) == false {
            log.severe("failed to add input")
            return false
        }
        self.videoSession.addInput(self.videoInput)
        log.debug("input video device added to the capture session")
        
        return true
    }
    
    func initializeVideoOutput() -> Bool {
        log.debug("initializing video output session...")
        
        self.videoOutput = AVCaptureVideoDataOutput()
        self.videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey:Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey:160,
            kCVPixelBufferHeightKey:120,
        ]
        
        // fps (just use lowest one)
        do {
            try self.videoDevice.lockForConfiguration()
        } catch _ {
            log.severe("failed to lock for configuration")
            return false
        }
        
        var frameDuration:CMTime?
        for frameRateRange in self.videoDevice.activeFormat.videoSupportedFrameRateRanges {
            let frameRateRange = frameRateRange as! AVFrameRateRange
            
            if frameDuration == nil || frameDuration < frameRateRange.minFrameDuration {
                frameDuration = frameRateRange.minFrameDuration
            }
        }
        if frameDuration == nil {
            log.severe("failed to discover frame duration")
            return false
        }
        self.videoDevice.activeVideoMinFrameDuration = frameDuration!
        self.videoDevice.unlockForConfiguration()
        
        self.videoOutput.alwaysDiscardsLateVideoFrames = true
        
        // dispatch queue
        let queue:dispatch_queue_t = dispatch_queue_create("videoQueue", DISPATCH_QUEUE_SERIAL)
        self.videoOutput.setSampleBufferDelegate(self, queue: queue)
        
        if self.videoSession.canAddOutput(self.videoOutput) == false {
            log.severe("failed to add output")
            return false
        }
        self.videoSession.addOutput(self.videoOutput)
        
        for connection in self.videoOutput.connections {
            if let c = connection as? AVCaptureConnection {
                if c.supportsVideoOrientation {
                    c.videoOrientation = AVCaptureVideoOrientation.Portrait
                }
            }
        }
        
        return true
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // nah :-P
        self.captureCounter++;
        if captureCounter % 2 != 0 {
            return
        }
        
        let image = self.getNSImageFromSampleBuffer(didOutputSampleBuffer: sampleBuffer)
        let found = self.recognizer.recognize(image)
        let event = self.updateState(found);
        if event != Events.None {
            log.debug("updating focus: \(event)")
            if event == Events.Front {
                self.focusFrontWindow(0, displayTo: 2560)
            } else if event == Events.Profile {
                self.focusFrontWindow(2560, displayTo: 5120)
            }
        }
    }
    
    func getNSImageFromSampleBuffer(didOutputSampleBuffer sampleBuffer:CMSampleBuffer!) -> NSImage! {
        let imageBuffer:CVImageBufferRef! = CMSampleBufferGetImageBuffer(sampleBuffer)
        if imageBuffer == nil {
            return nil
        }
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        let baseAddress:UnsafeMutablePointer<Void> = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace:CGColorSpaceRef! = CGColorSpaceCreateDeviceRGB()
        let bitsPerCompornent:Int = 8
        let bitmapInfo = CGBitmapInfo(rawValue:(CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue))
        let newContext:CGContextRef! = CGBitmapContextCreate(baseAddress, width, height, bitsPerCompornent, bytesPerRow, colorSpace, bitmapInfo.rawValue)
        
        let imageRef:CGImageRef! = CGBitmapContextCreateImage(newContext)
        let imageSize:CGSize! = CGSizeMake(CGFloat(width), CGFloat(height))
        let image:NSImage! = NSImage(CGImage:imageRef, size:NSSizeFromCGSize(imageSize))
        
        return image
    }
    
    func updateState(found:UInt32) -> Events {
        if self.state == found {
            self.stateProfileConfirmation = 0
            return Events.None
        } else if found == 0 {
            self.stateProfileConfirmation = 0
            return Events.None
        }
        
        let current = self.state
        if (found & Application.STATE_FRONTAL) > 0 {
            self.stateProfileConfirmation = 0
            self.state = Application.STATE_FRONTAL
            if current != Application.STATE_FRONTAL {
                return Events.Front
            }
        } else if (found & Application.STATE_PROFILE) > 0 {
            self.stateProfileConfirmation++
            
            if self.stateProfileConfirmation > 2 {
                self.state = Application.STATE_PROFILE
                if current != Application.STATE_PROFILE {
                    return Events.Profile
                }
            }
        }
        
        return Events.None
    }
    
    func focusFrontWindow(displayFrom:Int, displayTo:Int) {
        let windows:CFArrayRef! = CGWindowListCopyWindowInfo(CGWindowListOption(rawValue: (1 << 0) | (1 << 1) | (1 << 4)), CGWindowID(0)) // why, kCGWindowListOption* is unresolved...
        let n = CFArrayGetCount(windows)
        
        var windowNumber:Int = 0
        var windowOwnerPID:Int = 0
        var windowName:String = ""
        for i in 0..<n {
            let w = unsafeBitCast(CFArrayGetValueAtIndex(windows, i), CFDictionaryRef.self) as Dictionary
            
            // filter by layer/name
            let layer = w[kCGWindowLayer] as! Int
            if layer != 0 {
                continue
            }
            let name = w[kCGWindowName] as! String
            if name == "" {
                continue
            }
            
            // and check out window position
            let rect = w[kCGWindowBounds] as! CFDictionaryRef as Dictionary
            let x = rect["X"] as! Int
            if x < displayFrom || x >= displayTo {
                continue
            }
            
            // fetch windowNumber, ownerPID
            windowNumber = w[kCGWindowNumber] as! Int
            windowOwnerPID = w[kCGWindowOwnerPID] as! Int
            windowName = name
            break
        }
        if windowNumber == 0 && windowOwnerPID == 0 {
            // no possible window found
            return
        }
        
        // ok, focus it
        log.debug("name: \(windowName)")
        let element:AXUIElementRef = AXUIElementCreateApplication(Int32(windowOwnerPID)).takeRetainedValue() as AXUIElementRef
        AXUIElementSetAttributeValue(element, kAXFrontmostAttribute, kCFBooleanTrue as CFTypeRef)
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute, kCFBooleanTrue as CFTypeRef) // required?
    }
}