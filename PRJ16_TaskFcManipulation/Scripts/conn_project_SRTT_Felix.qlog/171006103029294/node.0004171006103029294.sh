#!/bin/bash
/usr/local/apps/Matlab/R2017a/bin/matlab -nodesktop -nodisplay -nosplash -singleCompThread -logfile '/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/Scripts/conn_project_SRTT_Felix.qlog/171006103029294/node.0004171006103029294.stdlog' -r "addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/spm12/spm12; addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/conn17f/conn; cd /gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/Scripts/conn_project_SRTT_Felix.qlog/171006103029294; conn_jobmanager('rexec','/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/Scripts/conn_project_SRTT_Felix.qlog/171006103029294/node.0004171006103029294.mat'); exit"
echo _NODE END_
