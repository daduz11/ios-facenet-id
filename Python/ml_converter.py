"""
   Copyright 2020 daduz11

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
"""


"""
Firstly this script is used for the conversion of the freezed inference graph (pb format) into a CoreML model.
Moreover the same script takes the CoreML model at 32bit precision to carries out the quantization from 16 to 1 bit.
"""
import argparse
import sys
import tfcoreml
import coremltools
from coremltools.models.neural_network import quantization_utils


def main(args):
    if args.type == 'FLOAT32':
        if args.model_dir[-3:] != '.pb':
            print("Error: the model type must be .pb file")
            return
        else:
            coreml_model = tfcoreml.convert(
                    tf_model_path=args.model_dir,
                    mlmodel_path=args.output_file,
                    input_name_shape_dict = {'input':[1,160,160,3]},
                    output_feature_names=["embeddings"],
                    minimum_ios_deployment_target = '13'
            )
            return
    else:
        if args.model_dir[-8:] != '.mlmodel':
            print("Error: the model type must be .mlmodel")
            return
        if args.type == 'FLOAT16':
            model_spec = coremltools.utils.load_spec(args.model_dir)
            model_fp16_spec = coremltools.utils.convert_neural_network_spec_weights_to_fp16(model_spec)
            coremltools.utils.save_spec(model_fp16_spec,args.output_file)
            return
        else:
            model = coremltools.models.MLModel(args.model_dir)
            bit = int(args.type[-1])
            print("quantization in INT" + str(bit))
            quantized_model = quantization_utils.quantize_weights(model, bit, "linear")
            quantized_model.save(args.output_file)
            return
    print('File correctly saved in:', args.output_file)
        


def parse_arguments(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('model_dir', type=str,
        help='This argument will be: .pb file for FLOAT32, .mlmodel otherwise (model quantization)')
    parser.add_argument('output_file', type=str,
        help='Filename for the converted coreml model (.mlmodel)')
    parser.add_argument('--type', type=str, choices=['FLOAT32','FLOAT16','INT8','INT6','INT4','INT3','INT2','INT1'], help="embeddings' type", default='FLOAT32')
    return parser.parse_args(argv)


if __name__ == '__main__':
    main(parse_arguments(sys.argv[1:]))
