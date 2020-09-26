"""
NOTE: MUST BE INSERTED INTO A davidsandberg's FOLDER "facenet/src"

This script gets the embeddings of each image into the dataset using the mlmodel
file produced by ml_converter.py script. These embeddings are put into a numpy 
array that is used to train the scikit-learn classifier. The classifier then is 
converted to mlmodel.
A labels txt file is also produced, where each row is a person folder's name.

The procedure can be improved, because the images of each person are passed one 
by one to the model for the extraction of the features.
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import tensorflow as tf
import numpy as np
import argparse
import facenet
import os
import sys
import math
import pickle
from sklearn.svm import SVC
import coremltools
import collections
import imageio
import time


def main(args):
    with tf.Graph().as_default():
        with tf.Session() as sess:
            np.random.seed(seed=args.seed)
            
            if args.use_split_dataset:
                dataset_tmp = facenet.get_dataset(args.data_dir)
                train_set, test_set = split_dataset(dataset_tmp, args.min_nrof_images_per_class, args.nrof_train_images_per_class)
                dataset = train_set
            else:
                dataset = facenet.get_dataset(args.data_dir)

            # Check that there are at least one training image per class
            for cls in dataset:
                assert(len(cls.image_paths)>0, 'There must be at least one image for each class in the dataset')
                 
            paths, labels = facenet.get_image_paths_and_labels(dataset)
            
            print('Number of classes: %d' % len(dataset))
            print('Number of images: %d' % len(paths))
            nrof_images = len(paths)

            # Load the model
            print('Loading feature extraction model')
            mlmodel = coremltools.models.MLModel(args.model)
            
            #Allocate output array: ((num_images, num_embeddings), type)
            emb_array = np.zeros((nrof_images,512), dtype=np.float32)

            print('Calculating features for images')
            
            start_time = time.time()
            
            if args.is_image:
                for i in range(0, nrof_images):
                    input_img = Image.open(paths[i])
                    # Prediction is run on CPU
                    coreml_output = mlmodel.predict({"input": input_img}, useCPUOnly=True)

                    #Gets and write the embeddings
                    emb_array[i] = np.asarray(coreml_output["embeddings"][0])
                    print('Completed', i+1, 'of', nrof_images)
            else:
                for i in range(0, nrof_images):
                    input_img = paths[i]
                    #Normalize input
                    image = prewhiten(input_img)
                    #allocate new input array
                    input_data = np.zeros((1, args.image_size, args.image_size, 3))
                    input_data[0,:,:,:] = image
                    input_dict = {}
                    input_dict['input'] = input_data
                    #coreml_output = mlmodel.predict(input_dict, useCPUOnly=True)
                    coreml_output = mlmodel.predict(input_dict)

                    #Gets and write the embeddings
                    emb_array[i] = np.asarray(coreml_output["embeddings"][0])
                    print('Completed', i+1, 'of', nrof_images)
                
            classifier_filename_exp = os.path.expanduser(args.classifier_filename)

            # Train classifier
            print('Training classifier')
            model = SVC(kernel='linear', probability=True)
            model.fit(emb_array, labels)
            
            run_time = time.time() - start_time
            print('Run time: ', run_time)
        
            # Create a list of class names
            class_names = [ cls.name.replace('_', ' ') for cls in dataset]
            
            # Convert the SVC classifier to Apple CoreML model
            coreml_model = coremltools.converters.sklearn.convert(model)
            coreml_model.save(classifier_filename_exp)

            #create labels file
            path_exp = os.path.expanduser(args.data_dir)
            classes = [path for path in os.listdir(path_exp) \
                       if os.path.isdir(os.path.join(path_exp, path))]
            classes.sort()

            label_strings = [name for name in classes if \
               os.path.isdir(os.path.join(path_exp, name))]

            label_strings = np.array(label_strings)

            output_labels = classifier_filename_exp + 'labels.txt'
            f_labels = open(output_labels, 'w')
            with f_labels:
                labels = list(collections.OrderedDict.fromkeys(label_strings).keys())
                for label in labels:
                    line = label +"\n"
                    f_labels.write(line)
            print(classifier_filename_exp + ".mlmodel created successfully")
            print(output_labels + ' created successfully')


def prewhiten(x):
    try:
        x = imageio.imread(x)
    except:
        print('Image is corrupt!')
        return 0
    mean = np.mean(x)
    std = np.std(x)
    std_adj = np.maximum(std, 1.0/np.sqrt(x.size))
    y = np.multiply(np.subtract(x, mean), 1/std_adj)
    return y



def split_dataset(dataset, min_nrof_images_per_class, nrof_train_images_per_class):
    train_set = []
    test_set = []
    for cls in dataset:
        paths = cls.image_paths
        # Remove classes with less than min_nrof_images_per_class
        if len(paths)>=min_nrof_images_per_class:
            np.random.shuffle(paths)
            train_set.append(facenet.ImageClass(cls.name, paths[:nrof_train_images_per_class]))
            test_set.append(facenet.ImageClass(cls.name, paths[nrof_train_images_per_class:]))
    return train_set, test_set




def parse_arguments(argv):
    parser = argparse.ArgumentParser()
    
    parser.add_argument('data_dir', type=str,
        help='Path to the data directory containing aligned LFW face patches.')
    parser.add_argument('model', type=str,
        help='Could be either a directory containing the meta_file and ckpt_file or a model protobuf (.ml) file')
    parser.add_argument('classifier_filename',
        help='Classifier model file name as a (.mlmodel) file. ' +
        'For training this is the output and for classification this is an input.')
    parser.add_argument('--use_split_dataset',
        help='Indicates that the dataset specified by data_dir should be split into a training and test set. ' +
        'Otherwise a separate test set can be specified using the test_data_dir option.', action='store_true')
    parser.add_argument('--test_data_dir', type=str,
        help='Path to the test data directory containing aligned images used for testing.')
    parser.add_argument('--image_size', type=int,
        help='Image size (height, width) in pixels.', default=160)
    parser.add_argument('--seed', type=int,
        help='Random seed.', default=666)
    parser.add_argument('--min_nrof_images_per_class', type=int,
        help='Only include classes with at least this number of images in the dataset', default=20)
    parser.add_argument('--nrof_train_images_per_class', type=int,
        help='Use this number of images from each class for training and the rest for testing', default=10)
    parser.add_argument('--is_image', type=str,
        help='Insert if the input is an RGB image and not MLMultiArray')

    
    return parser.parse_args(argv)

if __name__ == '__main__':
    main(parse_arguments(sys.argv[1:]))

