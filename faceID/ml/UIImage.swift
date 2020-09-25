//
//  ImageUtils.swift
//  faceID
//
//  Created by Davide on 20/05/2020.
//  Copyright © 2020 Davide. All rights reserved.
//

import Foundation
import UIKit
import CoreML
import VideoToolbox


extension UIImage {
   
    static func getUI(buffer: CVPixelBuffer) -> UIImage?{
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let temporaryContext = CIContext(options: nil)
        if let temporaryImage = temporaryContext.createCGImage(ciImage,from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
        {
            return UIImage(cgImage: temporaryImage)
        }
        return nil
    }
    
    func cropFace(_ inputCGImage: CGImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage?
    {
        let imageViewScale = max(self.size.width / viewWidth,
                                 self.size.height / viewHeight)
        // Scale cropRect to handle images larger than shown-on-screen size
        let cropZone = CGRect(x:cropRect.origin.x * imageViewScale,
                              y:cropRect.origin.y * imageViewScale,
                              width:cropRect.size.width * imageViewScale,
                              height:cropRect.size.height * imageViewScale)
        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = inputCGImage.cropping(to:cropZone) else {return nil}
        return resize(croppedimage: UIImage(cgImage: cutImageRef))
    }

      func resize(croppedimage: UIImage) -> UIImage{
        //resize to 160x160 square
        let newWidth:CGFloat = 160
        let newHeight:CGFloat = 160
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newWidth, height: newHeight), true, 3.0)
        croppedimage.draw(in: CGRect(x:0, y:0, width:newWidth, height:newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }

    //RGBA => 32bit => 4x8
    func getPixelData(buffer :inout [Double]){
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        //removes the alpha channel
        let n = 4
        let newCount = pixelData.count - pixelData.count/4
        buffer = (0..<newCount).map { Double(pixelData[$0 + $0/(n - 1)])}
    }
    

    func prewhiten(input :inout [Double], output :inout MLMultiArray){
        var sum :Double = Double(input.reduce(0, +))
        let mean :Double = sum / Double(input.count)
        
        sum = 0xF
        for i in 0..<input.count {
            input[i] = input[i] - mean
            sum += pow(input[i],2)
        }
        
        let std :Double = sqrt(sum/Double(input.count))
        let std_adj :Double = max(std, 1.0/sqrt(Double(input.count)))

        var  i = 0
        for value in input{
            output[i] = NSNumber(value: Float32(value/std_adj))
            i += 1
        }
    }

    

    //**************************** DEBUG ****************************
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }

        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)

            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

            context?.translateBy(x: 0, y: self.size.height)
            context?.scaleBy(x: 1.0, y: -1.0)

            UIGraphicsPushContext(context!)
            self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
            UIGraphicsPopContext()
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            return pixelBuffer
        }
        return nil
    }
    //***************************************************************

}
