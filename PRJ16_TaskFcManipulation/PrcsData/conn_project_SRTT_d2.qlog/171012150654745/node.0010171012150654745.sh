#!/bin/bash
/usr/local/apps/Matlab/R2017a/bin/matlab -nodesktop -nodisplay -nosplash -singleCompThread -logfile '/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d2.qlog/171012150654745/node.0010171012150654745.stdlog' -r "addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/spm12/spm12; addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/conn17f/conn; cd /gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d2.qlog/171012150654745; conn_jobmanager('rexec','/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d2.qlog/171012150654745/node.0010171012150654745.mat'); exit"
echo _NODE END_
