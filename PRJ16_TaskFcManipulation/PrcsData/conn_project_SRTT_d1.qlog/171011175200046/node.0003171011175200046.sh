#!/bin/bash
/usr/local/apps/Matlab/R2017a/bin/matlab -nodesktop -nodisplay -nosplash -singleCompThread -logfile '/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046/node.0003171011175200046.stdlog' -r "addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/spm12/spm12; addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/conn17f/conn; cd /gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046; conn_jobmanager('rexec','/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046/node.0003171011175200046.mat'); exit"
echo _NODE END_
