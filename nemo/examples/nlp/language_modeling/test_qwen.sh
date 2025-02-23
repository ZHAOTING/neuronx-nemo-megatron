#!/usr/bin/env bash

source ./train_setup.sh

: ${TOKENIZER_PATH=/fsx/qwen-14b-hf}
: ${DATASET_PATH=$HOME/examples_datasets/qwen/book.jsonl-processed_text_document}

echo "SEQ_LEN=$SEQ_LENGTH, HS=$HS, FFN_HS=$FFN_HS TP=$TP PP=$PP N_LAYERS=$N_LAYERS N_AH=$N_AH GBS=$GBS UBS=$UBS TRAIN_ITERS=$TRAIN_ITERS"


$MAYBE_COMPILE torchrun $DISTRIBUTED_ARGS megatron_gpt_pretraining.py  \
    --config-path=conf \
    --config-name=megatron_qwen_config \
    trainer.devices=$PROCESSES_PER_NODE \
    trainer.num_nodes=$NTASKS \
    trainer.max_epochs=null \
    trainer.max_steps=$TRAIN_ITERS\
    trainer.val_check_interval=$VALIDATE_INTERVAL \
    trainer.log_every_n_steps=1 \
    trainer.limit_val_batches=1 \
    trainer.limit_test_batches=1 \
    trainer.accumulate_grad_batches=1 \
    trainer.precision=32 \
    model.megatron_amp_O2=$megatron_amp_O2 \
    model.tokenizer.type=$TOKENIZER_PATH \
    model.micro_batch_size=$UBS \
    model.global_batch_size=$GBS \
    model.tensor_model_parallel_size=$TP \
    model.pipeline_model_parallel_size=$PP \
    model.max_position_embeddings=$SEQ_LENGTH \
    model.encoder_seq_length=$SEQ_LENGTH \
    model.hidden_size=$HS \
    model.ffn_hidden_size=$FFN_HS \
    model.num_layers=$N_LAYERS \
    model.num_attention_heads=$N_AH \
    model.init_method_std=$INIT_METHOD_STD \
    model.hidden_dropout=0 \
    model.layernorm_epsilon=$LAYERNORM_EPSILON \
    model.data.data_prefix=[1.0,$DATASET_PATH] \
    model.data.num_workers=1 \
    model.data.seq_length=$SEQ_LENGTH \
    model.optim.name=$OPTIM_NAME \
    model.optim.lr=3.0e-5 \
    model.optim.betas=[0.9,0.95] \
    model.optim.weight_decay=0.1 \
    model.optim.sched.name=CosineAnnealing \
    model.optim.sched.warmup_steps=$WARMUP_STEPS \
    model.optim.sched.constant_steps=0 \
    model.optim.sched.min_lr=3.0e-6 \
    model.optim.capturable=True \
    model.sequence_parallel=True  \
    model.activations_checkpoint_granularity=full \
    model.activations_checkpoint_method=uniform \
    model.activations_checkpoint_num_layers=1 \
    model.make_vocab_size_divisible_by=32\
    +model.save_xser=True\
    exp_manager.create_tensorboard_logger=$CREATE_TB_LOGGER \
    exp_manager.resume_if_exists=True \
    exp_manager.resume_ignore_no_checkpoint=True \
    exp_manager.create_checkpoint_callback=$CHECKPOINT_CALLBACK \
    exp_manager.explicit_log_dir=$EXPLICIT_LOGDIR \
    +exp_manager.checkpoint_callback_params.train_time_interval=$SAVE_CHECKPOINT_INTERVAL \
    exp_manager.checkpoint_callback_params.save_top_k=3 \
    model.use_cpu_initialization=False \
    +model.load_xser=True \
    model.resume_from_checkpoint=$LOAD_CHECKPOINT_FROM \
    2>&1 | tee -a $LOG_PATH/log

# Note: to resume training using a checkpoint, please add the following configuration above, adjusting for your checkpoint path
#    model.use_cpu_initialization=False \
#    +model.load_xser=True \
#    model.resume_from_checkpoint='/efs/checkpoint/megatron_gpt--step\=1085-consumed_samples\=69632.0-last.ckpt' \
