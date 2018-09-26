#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
CLUSTER=$2
TMPL_DIR=$(dirname $0)/../templates

echo "Setting up Nexus in project $GUID-nexus"

oc -n $GUID-nexus new-app -f ${TMPL_DIR}/nexus.yaml
oc -n $GUID-nexus rollout status dc/nexus3 -w
