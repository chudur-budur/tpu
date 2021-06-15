#!/bin/bash

MODEL_NAME="spine190retina"
EXPORT_DIR="../checkpoints/${MODEL_NAME?}-pb"
CHECKPOINT_PATH="../checkpoints/${MODEL_NAME?}/model.ckpt"
CONFIG_FILE="../checkpoints/${MODEL_NAME?}/config.yaml"
PARAMS_OVERRIDE=""  # if any.
BATCH_SIZE=1
INPUT_TYPE="image_bytes"
INPUT_NAME="input"
INPUT_IMAGE_SIZE="640,640"
PYTHONPATH="$PYTHONPATH:$WORKDIR/tpu/models:$WORKDIR/tpu/models/official/efficientnet" python ../models/official/detection/export_saved_model.py \
  --export_dir="${EXPORT_DIR?}" \
  --checkpoint_path="${CHECKPOINT_PATH?}" \
  --config_file="${CONFIG_FILE}" \
  --params_override="${PARAMS_OVERRIDE?}" \
  --batch_size=${BATCH_SIZE?} \
  --input_type="${INPUT_TYPE?}" \
  --input_name="${INPUT_NAME?}" \
  --input_image_size="${INPUT_IMAGE_SIZE?}" \

# SAVED_MODEL_DIR="detection_maskrcnn_spinenet-190"
# OUTPUT_DIR="detection_maskrcnn_spinenet-190-tfl"
# python models/official/detection/export_tflite_model.py \
#   --saved_model_dir="${SAVED_MODEL_DIR?}" \
#   --output_dir="${OUTPUT_DIR?}" \
