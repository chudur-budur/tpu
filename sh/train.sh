TPU_NAME="nod-v38-00"
# DATA_ROOT="/nodclouddata/mscoco/coco2017"
DATA_ROOT="gs://noddata/mscoco/coco2017"
PROJECT_ROOT="$HOME/tpu/models"
# MODEL_ROOT="$HOME/trained-models"
MODEL_ROOT="gs://noddata/khaled/trained-models"
TRAIN_FILE_PATTERN="$DATA_ROOT/train/train-*"
EVAL_FILE_PATTERN="$DATA_ROOT/val/val-*"
VAL_JSON_FILE="$DATA_ROOT/annotations/instances_val2017.json"
# RESNET_CHECKPOINT="gs://cloud-tpu-artifacts/resnet/resnet-nhwc-2018-10-14/model.ckpt-112602"
# TPU_SPLIT_COMPILE_AND_EXECUTE=1 \
PYTHONPATH="$PYTHONPATH:$PROJECT_ROOT:$PROJECT_ROOT/official/efficientnet" \
    python $PROJECT_ROOT/official/detection/main.py \
        --model=mask_rcnn \
        --model_dir="${MODEL_ROOT?}" \
        --use_tpu=True \
        --tpu="${TPU_NAME?}" \
        --num_cores=8 \
        --mode=train \
        --eval_after_training=True \
        --config_file="${PROJECT_ROOT?}/official/detection/configs/spinenet/spinenet49_mrcnn.yaml" \
        --params_override="{ train: { train_file_pattern: ${TRAIN_FILE_PATTERN?}, train_batch_size: 64 }, eval: { val_json_file: ${VAL_JSON_FILE?}, eval_file_pattern: ${EVAL_FILE_PATTERN?} } }"