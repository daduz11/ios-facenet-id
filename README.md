#  Realtime iOS Face Identifier


This project was carried out for an assignment of Digital Systems course at the University of Bologna. 

The proposal provides the implementation of real time face recognizer using [CoreML](https://developer.apple.com/documentation/coreml) and [Facenet](https://arxiv.org/abs/1503.03832).

## Folders

* Python: contains two scripts that produce the CoreML model, the SVC classifier and the labels txt file. Note that the classifier has been trained directly using the embeddings extracted from the CoreML model.  
* XCode: contains the source code of the project that can be easily imported.

## Inspiration
The project is inspired by
* [FaceNet](https://github.com/davidsandberg/facenet)
* [Android Implementation](https://github.com/pillarpond/face-recognizer-android)
* [iOSFacetracker](https://github.com/anuragajwani/FaceTracker)

## Demo
The bounding box is blue with the name and accuracy for people who are into the dataset, red otherwise if the accuracy is less than 0.4. The bounding box switching is slow due to the limited hardware available (iPad mini late 2015).


<img src="https://github.com/daduz11/ios-facenet-id/blob/master/demo.gif" width="270" align="left">
<img src="https://github.com/daduz11/ios-facenet-id/blob/master/main.png" width="230" align="left">
<img src="https://github.com/daduz11/ios-facenet-id/blob/master/list.png" width="230" align="center">




## Pre-trained model
from davidsandberg's facenet:

| Model name      | LFW accuracy | Training dataset | Architecture |
|-----------------|--------------|------------------|-------------|
| [20180402-114759](https://drive.google.com/open?id=1EXPBSXwTaqrSC0OhUdXNmKSh9qJUQ55-) | 0.9965        | VGGFace2      | [Inception ResNet v1](https://github.com/davidsandberg/facenet/blob/master/src/models/inception_resnet_v1.py) |


## License
[Apache License 2.0](./LICENSE)
