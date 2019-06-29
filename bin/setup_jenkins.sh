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
oc new-project ${GUID}-jenkins
sleep 2
oc new-app jenkins-persistent

# Create custom agent container image with skopeo
export JENKINS_AGENT=jenkins-agent-appdev
mkdir ${JENKINS_AGENT} && cd ${JENKINS_AGENT}
oc new-build --name=${JENKINS_AGENT} --binary=true

cat <<EOF > Dockefile
FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11
USER root
RUN yum -y install skopeo && yum clean all
USER 1001
EOF
oc start-build ${JENKINS_AGENT} --from-directory=.

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
oc new-build --name=jenkins-pipeline --context-dir=openshift-tasks --strategy=pipeline --env=GUID=${GUID} --env=REPO=${REPO} --env=CLUSTER=${CLUSTER}

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done

## My stuff
#export GUID=f355
#export APP=app
#
## Create new project to host Jenkins
#oc new-project ${GUID}-jenkins
#
## Deploy Jenkins master persistent
#oc new-app jenkins-persistent
#
## Create custom agent for Jenkins
#export JENKINS_AGENT=jenkins-agent-appdev
#mkdir ${JENKINS_AGENT} && cd ${JENKINS_AGENT}
#oc new-build --name=${JENKINS_AGENT} --binary=true
#
#cat <<EOF > Dockefile
#FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11
#USER root
#RUN yum -y install skopeo && yum clean all
#USER 1001
#EOF
#oc start-build ${JENKINS_AGENT} --from-directory=.
