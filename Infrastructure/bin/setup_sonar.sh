#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
TMPL_DIR=$(dirname $0)/../templates

echo "Setting up Sonarqube in project $GUID-sonarqube"

oc -n $GUID-sonarqube new-app -f ${TMPL_DIR}/sonarqube.yaml
oc -n $GUID-sonarqube rollout status dc/sonarqube -w


