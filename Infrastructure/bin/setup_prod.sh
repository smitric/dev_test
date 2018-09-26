#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
TMPL_DIR=$(dirname $0)/../templates
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

# Allow Jenkins (both from my project and grading project) to manipulate objects in Prod project
oc -n ${GUID}-parks-prod policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins
oc -n ${GUID}-parks-prod policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins

# Default permissions
oc -n ${GUID}-parks-prod policy add-role-to-user view --serviceaccount=default

# Config MongoDB configmap
oc -n ${GUID}-parks-prod create configmap parksdb-conf \
       --from-literal=DB_REPLICASET=rs0 \
       --from-literal=DB_HOST=mongodb \
       --from-literal=DB_PORT=27017 \
       --from-literal=DB_USERNAME=mongodb \
       --from-literal=DB_PASSWORD=mongodb \
       --from-literal=DB_NAME=parks

# Setup replicated MongoDB from templates + configure it via ConfigMap
oc -n ${GUID}-parks-prod new-app -f ${TMPL_DIR}/mongodb.yaml -p MONGO_CONFIGMAP_NAME=parksdb-conf
# Can't use oc rollout status sts/<name> -w due to Kubernetes bug: https://github.com/kubernetes/kubernetes/issues/52653
# oc -n ${GUID}-parks-prod rollout status sts/mongodb -w
# Have to check pod readiness using while loop
echo -n "Checking if replicated MongoDB is ready "
while : ; do
  oc get pod -n ${GUID}-parks-prod|grep '\-2'|grep -v deploy|grep "1/1"
  [[ "$?" == "1" ]] || break
  echo -n "."
  sleep 5
done
echo " [done]"

# Configuring MLB Parks backend microservice (Blue)
oc -n ${GUID}-parks-prod new-app ${GUID}-parks-dev/mlbparks:0.0 --allow-missing-images=true --allow-missing-imagestream-tags=true --name=mlbparks-blue -l type=parksmap-backend
oc -n ${GUID}-parks-prod set triggers dc/mlbparks-blue --remove-all
oc -n ${GUID}-parks-prod expose dc/mlbparks-blue --port 8080
oc -n ${GUID}-parks-prod set probe dc/mlbparks-blue --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod set probe dc/mlbparks-blue --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod create configmap mlbparks-blue-conf --from-literal=APPNAME="MLB Parks (Blue)"
oc -n ${GUID}-parks-prod set env dc/mlbparks-blue --from=configmap/mlbparks-blue-conf
oc -n ${GUID}-parks-prod set env dc/mlbparks-blue --from=configmap/parksdb-conf
oc -n ${GUID}-parks-prod set deployment-hook dc/mlbparks-blue --post -- curl -s http://mlbparks-blue:8080/ws/data/load/

# Configuring MLB Parks backend microservice (Green)
oc -n ${GUID}-parks-prod new-app ${GUID}-parks-dev/mlbparks:0.0 --allow-missing-images=true --allow-missing-imagestream-tags=true --name=mlbparks-green -l type=parksmap-backend-reserve
oc -n ${GUID}-parks-prod set triggers dc/mlbparks-green --remove-all
oc -n ${GUID}-parks-prod expose dc/mlbparks-green --port 8080
oc -n ${GUID}-parks-prod set probe dc/mlbparks-green --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod set probe dc/mlbparks-green --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod create configmap mlbparks-green-conf --from-literal=APPNAME="MLB Parks (Green)"
oc -n ${GUID}-parks-prod set env dc/mlbparks-green --from=configmap/mlbparks-green-conf
oc -n ${GUID}-parks-prod set env dc/mlbparks-green --from=configmap/parksdb-conf
oc -n ${GUID}-parks-prod set deployment-hook dc/mlbparks-green --post -- curl -s http://mlbparks-green:8080/ws/data/load/

# Configuring National Parks backend microservice (Blue)
oc -n ${GUID}-parks-prod new-app ${GUID}-parks-dev/nationalparks:0.0 --allow-missing-images=true --allow-missing-imagestream-tags=true --name=nationalparks-blue -l type=parksmap-backend
oc -n ${GUID}-parks-prod set triggers dc/nationalparks-blue --remove-all
oc -n ${GUID}-parks-prod expose dc/nationalparks-blue --port 8080
oc -n ${GUID}-parks-prod set probe dc/nationalparks-blue --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod set probe dc/nationalparks-blue --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod create configmap nationalparks-blue-conf --from-literal=APPNAME="National Parks (Blue)"
oc -n ${GUID}-parks-prod set env dc/nationalparks-blue --from=configmap/nationalparks-blue-conf
oc -n ${GUID}-parks-prod set env dc/nationalparks-blue --from=configmap/parksdb-conf
oc -n ${GUID}-parks-prod set deployment-hook dc/nationalparks-blue --post -- curl -s http://nationalparks-blue:8080/ws/data/load/

# Configuring National Parks backend microservice (Green)
oc -n ${GUID}-parks-prod new-app ${GUID}-parks-dev/nationalparks:0.0 --allow-missing-images=true --allow-missing-imagestream-tags=true --name=nationalparks-green -l type=parksmap-backend-reserve
oc -n ${GUID}-parks-prod set triggers dc/nationalparks-green --remove-all
oc -n ${GUID}-parks-prod expose dc/nationalparks-green --port 8080
oc -n ${GUID}-parks-prod set probe dc/nationalparks-green --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod set probe dc/nationalparks-green --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod create configmap nationalparks-green-conf --from-literal=APPNAME="National Parks (Green)"
oc -n ${GUID}-parks-prod set env dc/nationalparks-green --from=configmap/nationalparks-green-conf
oc -n ${GUID}-parks-prod set env dc/nationalparks-green --from=configmap/parksdb-conf
oc -n ${GUID}-parks-prod set deployment-hook dc/nationalparks-green --post -- curl -s http://nationalparks-green:8080/ws/data/load/

# Configuring Parks Map frontend microservice (Blue)
oc -n ${GUID}-parks-prod new-app ${GUID}-parks-dev/parksmap:0.0 --allow-missing-images=true --allow-missing-imagestream-tags=true --name=parksmap-blue -l type=parksmap-frontend
oc -n ${GUID}-parks-prod set triggers dc/parksmap-blue --remove-all
oc -n ${GUID}-parks-prod expose dc/parksmap-blue --port 8080
oc -n ${GUID}-parks-prod set probe dc/parksmap-blue --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod set probe dc/parksmap-blue --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod create configmap parksmap-blue-conf --from-literal=APPNAME="ParksMap (Blue)"
oc -n ${GUID}-parks-prod set env dc/parksmap-blue --from=configmap/parksmap-blue-conf

# Configuring Parks Map frontend microservice (Green)
oc -n ${GUID}-parks-prod new-app ${GUID}-parks-dev/parksmap:0.0 --allow-missing-images=true --allow-missing-imagestream-tags=true --name=parksmap-green -l type=parksmap-frontend
oc -n ${GUID}-parks-prod set triggers dc/parksmap-green --remove-all
oc -n ${GUID}-parks-prod expose dc/parksmap-green --port 8080
oc -n ${GUID}-parks-prod set probe dc/parksmap-green --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod set probe dc/parksmap-green --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
oc -n ${GUID}-parks-prod create configmap parksmap-green-conf --from-literal=APPNAME="ParksMap (Green)"
oc -n ${GUID}-parks-prod set env dc/parksmap-green --from=configmap/parksmap-green-conf

# Expose services
oc -n ${GUID}-parks-prod expose svc/parksmap-green --name parksmap
oc -n ${GUID}-parks-prod expose svc/mlbparks-green --name mlbparks
oc -n ${GUID}-parks-prod expose svc/nationalparks-green --name nationalparks
