#!/bin/bash
while true; do
    bash /tmp/superbowl/update.sh >> /tmp/superbowl/update.log 2>&1
    sleep 120
done
