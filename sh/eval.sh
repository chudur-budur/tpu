#/bin/bash
# A script to evaluate Masked-R-CNN with Spinenet-49 backbone on nod GCP TPU.
# It will pick the latest checkpoint from the $MODEL_ROOT folder.
# $./eval.sh

TPU_NAME="nod-v38-00"
DATA_ROOT="gs://noddata/mscoco/coco2017"
PROJECT_ROOT="$HOME/tpu/models"
MODEL_ROOT="gs://noddata/$USER/trained-models/spinenet49_mrcnn_bs64"
TRAIN_FILE_PATTERN="$DATA_ROOT/train/train-*"
EVAL_FILE_PATTERN="$DATA_ROOT/val/val-*"
VAL_JSON_FILE="$DATA_ROOT/annotations/instances_val2017.json"
# MODEL_CHECKPOINT="$MODEL_ROOT/model.ckpt-8900"
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
