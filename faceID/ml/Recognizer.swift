//
//  FaceNet.swift
//  faceID
//
//  Created by Davide on 20/05/2020.
//  Copyright © 2020 Davide. All rights reserved.
//

import UIKit
import CoreML
import AVFoundation
import Accelerate

class Recognizer
{
    //facenet model
    private let facenet = Facenet6()
    private let svc = SVC6()
    private let labels_file = "labels"
    
    private let EMBEDDINGS_SIZE :Int = 512
    private let INPUT_SIZE_HEIGHT :Int = 160
    private let INPUT_SIZE_WIDTH :Int = 160
    
    //picture buffers
    private var rgbValues :[Double] = []
    
    //model buffers
    private var inputBuffer :MLMultiArray?

    //labels dictionary
    private var labels :[String] = []

    //SVC and SVM prediction output
    public var target :Int64 = 0
    public var probability: Double = 0.0
    public var name :String = ""
 
    init(){
        getLabelsFromFile()
        
        //models' buffers allocation
        self.inputBuffer = try? MLMultiArray(shape: [1,NSNumber(value: INPUT_SIZE_HEIGHT), NSNumber(value: INPUT_SIZE_WIDTH), 3], dataType: MLMultiArrayDataType.float32)
        self.rgbValues = Array(repeating: 0.0, count: INPUT_SIZE_WIDTH*INPUT_SIZE_HEIGHT*3)
    }
    
    //gets embeddings of a picture using facenet model
    func recognize(image: UIImage){        
        image.getPixelData(buffer: &self.rgbValues)
        image.prewhiten(input: &self.rgbValues, output: &self.inputBuffer!)
        //print("PREWHITE: DONE")
        if let prediction = try? self.facenet.prediction(input: self.inputBuffer!){
            //print("FACENET prediction: DONE")
            self.predictFaceSVC(input: prediction.embeddings)
        }
        else {
            print("FACENET prediction: ERROR")
        }
    }
    
    
    //makes a prediction using sklearn classifier
    func predictFaceSVC(input: MLMultiArray){
        if let prediction = try? self.svc.prediction(input: input) {
            self.target = prediction.classLabel
            self.probability = prediction.classProbability[prediction.classLabel]!
            //print("SVC prediction: LABEL: ", self.target, "\tPROB: ", self.probability)
            if self.probability >= 0.4{
                self.name = self.labels[Int(self.target)]
            }
            else {
                self.name = "UNKNOW"
            }
        }
        else {
            print("SVC prediction: ERROR")
        }
    }

    //puts all labels into an array "labels"
    func getLabelsFromFile(){
        DispatchQueue.global(qos: .background).async {
            if let fileURL = Bundle.main.url(forResource: self.labels_file, withExtension: "txt"){
                do {
                    let text = try! String(contentsOf: fileURL)
                    let lines = text.components(separatedBy: "\n") as [String]
                    
                    //stores each line of file into a dictionary
                    for i in 0..<lines.count {
                        self.labels.append(lines[i])
                    }
                }
            }
        }
    }
    
}
