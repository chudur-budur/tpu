# Getting started

## Hardware Specs

* We have used GCP VM instance from the image `jenkins-image-7`
* For TPU, we have used [`v3-8`](https://cloud.google.com/tpu/docs/types-zones#types). 

## Installation

To get started, make sure you install Tensorflow 1.15+.

* **Most of the models for instance segmentation and detection require TPU for faster training and reproducing the results from the papers. Therefore, we recommend using TPU.** But in any case, for GPU training, make sure it has the GPU support. See the [guideline](https://www.tensorflow.org/install/gpu) by Tensorflow.

```bash
pip3 install tensorflow-gpu==1.15  # GPU
```

* For Cloud TPU / TPU Pods training, make sure Tensorflow 1.15+ is pre-installed in your Google Cloud VM.


Also, there are a few packages that you need to install.

```bash
sudo apt-get install -y python-tk && \
pip3 install --user Cython matplotlib opencv-python-headless pyyaml Pillow && \
pip3 install --user 'git+https://github.com/cocodataset/cocoapi#egg=pycocotools&subdirectory=PythonAPI'
```

**Please note: we didn't run any models from this code-base on GPU.**

## Dataset download and conversion

Next, download the latest code from [tpu github](https://github.com/tensorflow/tpu) repository.

```bash
git clone https://github.com/tensorflow/tpu/
```

The training expects the data in TFExample format stored in TFRecord.
Tools and scripts are provided to download and convert datasets.

|  Dataset  |      Tool     |
|:---------:|:-------------:|
| ImageNet  | [instructions](https://cloud.google.com/tpu/docs/classification-data-conversion) |
| COCO      | [instructions](https://cloud.google.com/tpu/docs/tutorials/retinanet#prepare_the_coco_dataset) |

### Special Note for Handling Data using TPU

TPU might not be able to [use your local file system](https://cloud.google.com/tpu/docs/troubleshooting#cannot_use_local_filesystem). Therefore, all the `TFRecords` data need to be kept on google cloud storage. In our case, we have organized the data as follows:

```
$gs://GS_ROOT
    + /mscoco
        + /coco2017
            + /annotations
            + /test-dev
            + /test
            + /train
            + /unlabeled
            + /val
```

## Model Training

We have trained Masked-R-CNN with Spinenet-49 backbone (`v3-8` can't train Spinenet-190). Had to keep the `train_batch_size: 64` (256 was not possible, because of resource exhaustion). Each step will take 2 sec. to compute, therefore completing 162050 steps will take 90 hours to finish. We have run the training for 16700 steps (i.e. 1/10-th of the total steps) and found 18% AP. The train command looks like this ([`train.sh`](https://github.com/chudur-budur/tpu/blob/master/sh/train.sh)):

```bash
TPU_NAME="$TPU_NAME"
DATA_ROOT="gs://$GS_ROOT/mscoco/coco2017"
PROJECT_ROOT="$HOME/tpu/models"
MODEL_ROOT="gs://$GS_ROOT/$USER/trained-models/spinenet49_mrcnn_bs64"
TRAIN_FILE_PATTERN="$DATA_ROOT/train/train-*"
EVAL_FILE_PATTERN="$DATA_ROOT/val/val-*"
VAL_JSON_FILE="$DATA_ROOT/annotations/instances_val2017.json"
# RESNET_CHECKPOINT="gs://cloud-tpu-artifacts/resnet/resnet-nhwc-2018-10-14/model.ckpt-112602"
# TPU_SPLIT_COMPILE_AND_EXECUTE=1 \
PYTHONPATH="$PYTHONPATH:$PROJECT_ROOT:$PROJECT_ROOT/official/efficientnet" \
    python $PROJECT_ROOT/official/detection/main.py \
        --use_tpu=True \
        --tpu="${TPU_NAME?}" \
        --num_cores=8 \
        --mode=train \
        --model=mask_rcnn \
        --model_dir="${MODEL_ROOT?}" \
        --eval_after_training=True \
        --config_file="${PROJECT_ROOT?}/official/detection/configs/spinenet/spinenet49_mrcnn.yaml" \
        --params_override="{ train: { train_file_pattern: ${TRAIN_FILE_PATTERN?}, train_batch_size: 64 }, eval: { val_json_file: ${VAL_JSON_FILE?}, eval_file_pattern: ${EVAL_FILE_PATTERN?} } }"
``` 

The config `.yaml` file for this experiment can be found [here](https://github.com/chudur-budur/tpu/blob/master/models/official/detection/configs/spinenet/spinenet49_mrcnn.yaml).

## Model Evaluation

We have done evaluation on the 16700-th checkpoint. Which can be found at `gs://$GS_ROOT/$USER/trained-models/spinenet49_mrcnn_bs64/`. The command looks like this:

```bash
TPU_NAME="$TPU_NAME"
DATA_ROOT="gs://$GS_ROOT/mscoco/coco2017"
PROJECT_ROOT="$HOME/tpu/models"
MODEL_ROOT="gs://$GS_ROOT/$USER/trained-models/spinenet49_mrcnn_bs64"
TRAIN_FILE_PATTERN="$DATA_ROOT/train/train-*"
EVAL_FILE_PATTERN="$DATA_ROOT/val/val-*"
VAL_JSON_FILE="$DATA_ROOT/annotations/instances_val2017.json"
# MODEL_CHECKPOINT="$MODEL_ROOT/model.ckpt-16700"
PYTHONPATH="$PYTHONPATH:$PROJECT_ROOT:$PROJECT_ROOT/official/efficientnet" \
    python $PROJECT_ROOT/official/detection/main.py \
        --use_tpu=True \
        --tpu="${TPU_NAME?}" \
        --num_cores=8 \
        --model=mask_rcnn \
        --mode=eval \
        --model_dir="${MODEL_ROOT?}" \
        --config_file="${PROJECT_ROOT?}/official/detection/configs/spinenet/spinenet49_mrcnn.yaml" \
        --params_override="{ eval: { val_json_file: ${VAL_JSON_FILE?}, eval_file_pattern: ${EVAL_FILE_PATTERN?} } }"
```

Since we have stopped training at 16700 steps (took 7.5 hrs to finish), the above script ([`eval.sh`](https://github.com/chudur-budur/tpu/blob/master/sh/eval.sh)) takes that checkpoint and evaluates it. The results we got was like this:

```
I0331 12:58:54.080487 140355357364608 tpu_executor.py:237] Eval result: {'AP': 0.18245085, 'AP50': 0.31578702, 'AP75': 0.19115251, 'APs': 0.063275196, 'APm': 0.18639816, 'APl': 0.28921905, 'ARmax1': 0.20520599, 'ARmax10': 0.31232253, 'ARmax100': 0.3235765, 'ARs': 0.12550662, 'ARm': 0.34083357, 'ARl': 0.47202468, 'mask_AP': 0.17229174, 'mask_AP50': 0.29583853, 'mask_AP75': 0.17775297, 'mask_APs': 0.05163716, 'mask_APm': 0.17771785, 'mask_APl': 0.28032523, 'mask_ARmax1': 0.19753762, 'mask_ARmax10': 0.29378796, 'mask_ARmax100': 0.3030697, 'mask_ARs': 0.103267014, 'mask_ARm': 0.32132158, 'mask_ARl': 0.45659247}
```

i.e. `AP 18.2%`, `AP50: 31.6%`, `AP75: 19.1%`, `APs: 6.3%`, `APm: 18.6%`. If you can run the experiment till end (which will take 90 hrs on `v3-8`), you might get the similar result reported in [the paper](https://arxiv.org/abs/1912.05027).

If you want to run [other (small) models](https://github.com/tensorflow/tpu/blob/master/models/official/detection/MODEL_ZOO.md#instance-segmentation-baselines), just follow the similar process. 

## Model Training (Misc.)

We support both GPU training on a single machine, and Cloud TPU / TPU Pods training.
Below we provide sample commands to launch RetinaNet training on different platforms.

### GPU training on a single machine

```bash
MODEL_DIR="<path to the directory to store model files>"
TRAIN_FILE_PATTERN="<path to the TFRecord training data>"
EVAL_FILE_PATTERN="<path to the TFRecord validation data>"
VAL_JSON_FILE="<path to the validation annotation JSON file>"
RESNET_CHECKPOINT="gs://cloud-tpu-artifacts/resnet/resnet-nhwc-2018-10-14/model.ckpt-112602"
python ~/tpu/models/official/detection/main.py \
  --model="retinanet" \
  --model_dir="${MODEL_DIR?}" \
  --mode=train \
  --eval_after_training=True \
  --use_tpu=False \
  --params_override="{ train: { checkpoint: { path: ${RESNET_CHECKPOINT?}, prefix: resnet50/ }, train_file_pattern: ${TRAIN_FILE_PATTERN?} }, eval: { val_json_file: ${VAL_JSON_FILE?}, eval_file_pattern: ${EVAL_FILE_PATTERN?} } }"
```

### Training on Cloud TPU

To train this model on Cloud TPU, you will need:

* A GCE VM instance with an associated Cloud TPU resource.
* A GCS bucket to store your training checkpoints (the `--model_dir` flag).
* Install TensorFlow 1.15+ for both GCE VM and Cloud TPU instances.

See the RetinaNet [tutorial](https://cloud.google.com/tpu/docs/tutorials/retinanet)
for more instructuions about TPU training.

```bash
TPU_NAME="<your GCP TPU name>"
MODEL_DIR="<path to the directory to store model files>"
TRAIN_FILE_PATTERN="<path to the TFRecord training data>"
EVAL_FILE_PATTERN="<path to the TFRecord validation data>"
VAL_JSON_FILE="<path to the validation annotation JSON file>"
RESNET_CHECKPOINT="gs://cloud-tpu-artifacts/resnet/resnet-nhwc-2018-10-14/model.ckpt-112602"
python ~/tpu/models/official/detection/main.py \
  --model="retinanet" \
  --model_dir="${MODEL_DIR?}" \
  --use_tpu=True \
  --tpu="${TPU_NAME?}" \
  --num_cores=8 \
  --mode=train \
  --eval_after_training=True \
  --params_override="{ train: { checkpoint: { path: ${RESNET_CHECKPOINT?}, prefix: resnet50/ }, train_file_pattern: ${TRAIN_FILE_PATTERN?} }, eval: { val_json_file: ${VAL_JSON_FILE?}, eval_file_pattern: ${EVAL_FILE_PATTERN?} } }"
```

### Training on Cloud TPU Pods

You can leverage large [Cloud TPU Pods](https://cloud.google.com/blog/products/ai-machine-learning/googles-scalable-supercomputers-for-machine-learning-cloud-tpu-pods-are-now-publicly-available-in-beta)
in Google Cloud to significantly improve the training performance.

```bash
TPU_POD_NAME="<your GCP TPU name>"
NUM_CORES=<num cores in TPU pod>  # e.g. v3-32 offers 32 cores.
MODEL_DIR="<path to the directory to store model files>"
TRAIN_FILE_PATTERN="<path to the TFRecord training data>"
EVAL_FILE_PATTERN="<path to the TFRecord validation data>"
VAL_JSON_FILE="<path to the validation annotation JSON file>"
RESNET_CHECKPOINT="gs://cloud-tpu-artifacts/resnet/resnet-nhwc-2018-10-14/model.ckpt-112602"
CONFIG=""
python ~/tpu/models/official/detection/main.py \
  --model="retinanet" \
  --model_dir="${MODEL_DIR?}" \
  --use_tpu=True \
  --tpu="${TPU_POD_NAME?}" \
  --num_cores=${NUM_CORES} \
  --mode=train \
  --config_file="" \
  --params_override="{ train: { checkpoint: { path: ${RESNET_CHECKPOINT?}, prefix: resnet50/ }, train_file_pattern: ${TRAIN_FILE_PATTERN?} }, eval: { val_json_file: ${VAL_JSON_FILE?}, eval_file_pattern: ${EVAL_FILE_PATTERN?} } }"
```

### Customize configurations

The framework supports three levels of parameter overrides to accommodate different use cases.

1. `<xxx>_config.py` under [`./configs`](https://github.com/chudur-budur/tpu/tree/master/models/official/detection/configs) directory.

  This defines and sets the default values of all the parameters required by the particular model.

2. `<xxx>.yaml` and override through the `--config_file` flag.

  This provides the first level override on top of the default defined by `<xxx>_config.py`.
  One can use it to define a controlled experiment by
  first defining a `.yaml` file as the template and passing to the `--config_file` flag
  and then changing only one or two parameters using the `--params_override` flag.

3. parameters in JSON string and override through the `--params_override` flag.

  This provides the final override on top of 1 and 2.

#### Example: Train RetinaNet using customized configurations.

First, create a YAML config file, e.g. *my_retinanet.yaml*,
to define training / evaluation dataset.

```YAML
# my_retinanet.yaml
type: 'retinanet'
train:
  train_file_pattern: <path to the TFRecord training data>
eval:
  eval_file_pattern: <path to the TFRecord validation data>
  val_json_file: <path to the validation annotation JSON file>
```

Override learning rate hyper-parameter via `--params_override` in the launch command.

```bash
python ~/tpu/models/official/detection/main.py \
  ... \
  --config_file="my_retinanet.yaml" \
  --params_override="{ train: { learnin_rate: { init_learning_rate: 0.2 } } }"
```

## Model Export

### Export to SavedModel

Given the checkpoint, one can easily export the [SavedModel](https://www.tensorflow.org/guide/saved_model) for serving using the following command.

```bash
EXPORT_DIR="<path to the directory to store the exported model>"
CHECKPOINT_PATH="<path to the checkpoint>"
PARAMS_OVERRIDE=""  # if any.
BATCH_SIZE=1
INPUT_TYPE="image_bytes"
INPUT_NAME="input"
INPUT_IMAGE_SIZE="640,640"
python ~/tpu/models/official/detection/export_saved_model.py \
  --export_dir="${EXPORT_DIR?}" \
  --checkpoint_path="${CHECKPOINT_PATH?}" \
  --params_override="${PARAMS_OVERRIDE?}" \
  --batch_size=${BATCH_SIZE?} \
  --input_type="${INPUT_TYPE?}" \
  --input_name="${INPUT_NAME?}" \
  --input_image_size="${INPUT_IMAGE_SIZE?}" \
```

### Export to TF-lite

Given the exported SavedModel, one can further convert it to the [TF-lite](https://www.tensorflow.org/lite) format that can be deployed on mobile platform.

```bash
SAVED_MODEL_DIR="<path to the SavedModel directory>"
OUTPUT_DIR="<path to the directory to store the tflite model>"
python ~/tpu/models/official/detection/export_tflite_model.py \
  --saved_model_dir="${SAVED_MODEL_DIR?}" \
  --output_dir="${OUTPUT_DIR?}" \
```

### Export to TensorRT

Given the exported SavedModel, one can further convert it to the [TensoRT](https://developer.nvidia.com/tensorrt) format that can be deployed on GPU platform.

```bash
SAVED_MODEL_DIR="<path to the SavedModel directory>"
OUTPUT_DIR="<path to the output TensorRT SavedModel directory>"
python ~/tpu/models/official/detection/export_tensorrt_model.py \
  --saved_model_dir="${SAVED_MODEL_DIR?}" \
  --output_dir="${OUTPUT_DIR?}" \
```

## Model Inference

### Use checkpoint

Given the checkpoint, one can easily run the model inference using the following command.

```bash
MODEL="retinanet"
IMAGE_SIZE=640
CHECKPOINT_PATH="<path to the checkpoint>"
PARAMS_OVERRIDE=""  # if any.
LABEL_MAP_FILE="~/tpu/models/official/detection/datasets/coco_label_map.csv"
IMAGE_FILE_PATTERN="<path to the JPEG image that you want to run inference on>"
OUTPUT_HTML="./test.html"
python ~/tpu/models/official/detection/inference.py \
  --model="${MODEL?}" \
  --image_size=${IMAGE_SIZE?} \
  --checkpoint_path="${CHECKPOINT_PATH?}" \
  --label_map_file="${LABEL_MAP_FILE?}" \
  --image_file_pattern="${IMAGE_FILE_PATTERN?}" \
  --output_html="${OUTPUT_HTML?}" \
  --max_boxes_to_draw=10 \
  --min_score_threshold=0.05
```

### Use SavedModel

One can also use the exported SavedModel, which a bundle of model weights and
graph computation, to run inference.

```bash
SAVED_MODEL_DIR="<path to the SavedModel>"
LABEL_MAP_FILE="~/tpu/models/official/detection/datasets/coco_label_map.csv"
IMAGE_FILE_PATTERN="<path to the JPEG image that you want to run inference on>"
OUTPUT_HTML="./test.html"
python ~/tpu/models/detection/inference_saved_model \
  --saved_model_dir="${SAVED_MODEL_DIR?}" \
  --label_map_file="${LABEL_MAP_FILE?}" \
  --image_file_pattern="${IMAGE_FILE_PATTERN?}" \
  --output_html="${OUTPUT_HTML?}" \
  --max_boxes_to_draw=10 \
  --min_score_threshold=0.05
```
