#!/bin/bash

# todo:  not used yet
# todo: start, stop , restart from scrript --- also create PID file from here

export PYTHONPATH=/usr/local/src/AgentV2/flask/bin:$PYTHONPATH:
export PATH=$PYTHONPATH:$PATH;

fold=`pwd`
cd /usr/local/src/AgentV2/
source /usr/local/src/AgentV2/flask/bin/activate
virtualenv flask
cd $fold

/usr/local/src/AgentV2/flask/bin/python3 /usr/local/src/AgentV2/NetworkAgentV2.py &

#action=$1
#case $action in
#   "start")
#        todo
#        ;;
#    "stop")
#        todo
#         ;;
#     *)
#      echo "Unsupport action"
#      ;;
#esac