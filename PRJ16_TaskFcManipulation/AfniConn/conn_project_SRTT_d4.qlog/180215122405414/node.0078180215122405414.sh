#!/bin/bash
/usr/local/apps/Matlab/R2017a/bin/matlab -nodesktop -nodisplay -nosplash -singleCompThread -logfile '/gpfs/gsfs8/users/jangrawdc/PRJ16_TaskFcManipulation/AfniConn/conn_project_SRTT_d4.qlog/180215122405414/node.0078180215122405414.stdlog' -r "addpath /gpfs/gsfs8/users/jangrawdc/MATLAB/Toolboxes/spm12/spm12; addpath /gpfs/gsfs8/users/jangrawdc/MATLAB/Toolboxes/conn17f/conn; cd /gpfs/gsfs8/users/jangrawdc/PRJ16_TaskFcManipulation/AfniConn/conn_project_SRTT_d4.qlog/180215122405414; conn_jobmanager('rexec','/gpfs/gsfs8/users/jangrawdc/PRJ16_TaskFcManipulation/AfniConn/conn_project_SRTT_d4.qlog/180215122405414/node.0078180215122405414.mat'); exit"
echo _NODE END_