#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
TMPL_DIR=$(dirname $0)/../templates

echo "Allowing Jenkins in grading project to edit resources in this Jenkins project"
oc -n ${GUID}-jenkins policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins

echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"
oc -n $GUID-jenkins new-app -f ${TMPL_DIR}/jenkins.yaml -p MEMORY_LIMIT=2Gi -p VOLUME_CAPACITY=4Gi
oc -n $GUID-jenkins rollout status dc/jenkins -w

echo "Building Jenkins Slave Maven"
cat ${TMPL_DIR}/jenkins-slave-maven.Dockerfile | oc -n $GUID-jenkins new-build --name=jenkins-slave-maven -D -
oc -n $GUID-jenkins logs -f bc/jenkins-slave-maven
oc -n $GUID-jenkins new-app -f ${TMPL_DIR}/jenkins-configmap.yaml --param GUID=${GUID}

echo "Creating and configuring Build Configs for 3 pipelines"
oc -n $GUID-jenkins new-build ${REPO} --name="mlbparks-pipeline" --strategy=pipeline --context-dir="MLBParks"
oc -n $GUID-jenkins set env bc/mlbparks-pipeline CLUSTER=${CLUSTER} GUID=${GUID}

oc -n $GUID-jenkins new-build ${REPO} --name="nationalparks-pipeline" --strategy=pipeline --context-dir="Nationalparks"
oc -n $GUID-jenkins set env bc/nationalparks-pipeline CLUSTER=${CLUSTER} GUID=${GUID}

oc -n $GUID-jenkins new-build ${REPO} --name="parksmap-pipeline" --strategy=pipeline --context-dir="ParksMap"
oc -n $GUID-jenkins set env bc/parksmap-pipeline CLUSTER=${CLUSTER} GUID=${GUID}

