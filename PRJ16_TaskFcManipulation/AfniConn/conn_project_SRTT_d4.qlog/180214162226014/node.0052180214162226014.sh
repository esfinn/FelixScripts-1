#!/bin/bash
/usr/local/apps/Matlab/R2017a/bin/matlab -nodesktop -nodisplay -nosplash -singleCompThread -logfile '/gpfs/gsfs8/users/jangrawdc/PRJ16_TaskFcManipulation/AfniConn/conn_project_SRTT_d4.qlog/180214162226014/node.0052180214162226014.stdlog' -r "addpath /gpfs/gsfs8/users/jangrawdc/MATLAB/Toolboxes/spm12/spm12; addpath /gpfs/gsfs8/users/jangrawdc/MATLAB/Toolboxes/conn17f/conn; cd /gpfs/gsfs8/users/jangrawdc/PRJ16_TaskFcManipulation/AfniConn/conn_project_SRTT_d4.qlog/180214162226014; conn_jobmanager('rexec','/gpfs/gsfs8/users/jangrawdc/PRJ16_TaskFcManipulation/AfniConn/conn_project_SRTT_d4.qlog/180214162226014/node.0052180214162226014.mat'); exit"
echo _NODE END_
