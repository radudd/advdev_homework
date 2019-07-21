#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"


# Set up Jenkins with sufficient resources
oc project ${GUID}-jenkins || oc new-project ${GUID}-jenkins

sleep 2
oc get dc jenkins 2>/dev/null
rt=$?
if [[ $rt -ne 0 ]] ; then
    oc new-app jenkins-persistent
    sleep 240
    # Make sure that Jenkins is fully up and running before proceeding!
    while : ; do
      AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
      if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
        echo "Jenkins is ready.. proceeding"
        break
      fi
      echo "Jenkins NOT ready.. Sleeping 10 seconds."
      sleep 10
    done
    oc set resources dc jenkins --requests=memory=1Gi,cpu=1 --limits=memory=2Gi,cpu=2
fi

# Create custom agent container image with skopeo
agent_deployed=$(oc get build | grep -c "jenkins-agent-appdev.*Complete")
if [[ $agent_deployed -eq 0 ]]; then
    export JENKINS_AGENT=jenkins-agent-appdev
    oc new-build --name ${JENKINS_AGENT} --dockerfile=$'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\nUSER root\nRUN yum -y install skopeo && yum clean all\nUSER 1001'
fi

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
oc get bc tasks-pipeline 2>/dev/null
rt=$?
if [[ $rt -ne 0 ]]; then 
  oc new-build $REPO --name=tasks-pipeline --context-dir=openshift-tasks --strategy=pipeline --env=GUID=${GUID} --env=REPO=${REPO} --env=CLUSTER=${CLUSTER}
fi

