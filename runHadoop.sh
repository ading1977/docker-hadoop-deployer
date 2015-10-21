#!/bin/bash

# The directory that stores customized Hadoop configuration files:wq
: ${HADOOP_DOCKER_IMAGE:=ading1977/hadoop:latest}
: ${HADOOP_LOG_DIR:=/opt/hadoop/logs}
: ${HADOOP_CONF_DIR:=/opt/hadoop/etc/hadoop}
: ${HADOOP_SHARED_DIR:=/root/shared}
: ${HADOOP_NAMENODE:=mdinglin02}
: ${HADOOP_RESOURCEMANAGER:=mdinglin02}
: ${HADOOP_DFS_REPLICATION:=1}

docker_hadoop_error() {
  echo "$*" 1>&2
}

docker_hadoop_usage() {
  echo "Usage: runHadoop.sh (namenode | datanode | resourcemanager | nodemanager)"
}

docker_hadoop_upgrade_image() {
  local IMAGE=${HADOOP_DOCKER_IMAGE}
  local CID=$(docker ps | grep $IMAGE | grep $DAEMON | awk '{print $1}')

  # Pull the latest image if available
  docker pull $IMAGE

  # Is the container running
  if [ -z $CID ]; then
    return 1
  fi

  LATEST=`docker inspect --format "{{.Id}}" $IMAGE`
  RUNNING=`docker inspect --format "{{.Image}}" $CID`
  echo "Latest:" $LATEST
  echo "Running:" $RUNNING
  if [ "$RUNNING" != "$LATEST" ]; then
    echo "upgrading $DAEMON image"
    docker stop $DAEMON
    docker rm -f $DAEMON
    return 1
  else
    echo "$DAEMON is running, and the image is up to date"
    return 0
  fi
}

docker_hadoop_expand_env() {
  DOCKER_ENVS=""
  for var in  ${!HADOOP_*}; do
    DOCKER_ENVS="${DOCKER_ENVS} -e $var=${!var}"
  done
}

docker_run() {

  docker_hadoop_upgrade_image
  if [ $? -eq 0 ]; then
    return 0
  fi

  docker run -d --name ${DAEMON} --net=host \
    -v ${HADOOP_LOG_DIR}:${HADOOP_LOG_DIR} \
    -v ${HADOOP_CONF_DIR}:${HADOOP_CONF_DIR} \
    -v ${HADOOP_SHARED_DIR}:${HADOOP_SHARED_DIR} \
    ${DOCKER_ENVS} \
    ${HADOOP_DOCKER_IMAGE} ${DAEMON}
}

if [[ $# = 0 ]]; then
  docker_hadoop_usage
  exit 1
fi


docker_hadoop_expand_env

DAEMON=$1
case ${DAEMON} in
  namenode)
    docker_run namenode
  ;;
  datanode)
    docker_run datanode
  ;;
  resourcemanager)
    docker_run resourcemanager
  ;;
  nodemanager)
    docker_run nodemanager
  ;;
  *)
    docker_hadoop_usage
    exit 1
  ;;
esac
