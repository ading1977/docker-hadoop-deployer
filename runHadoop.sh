#!/bin/bash

# The directory that stores customized Hadoop configuration files:wq
: ${HADOOP_DOCKER_IMAGE:=ading1977/hadoop:latest}
: ${HADOOP_LOG_DIR:=/opt/hadoop/logs}
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

docker_hadoop_expand_env() {
  DOCKER_ENVS=""
  for var in  ${!HADOOP_*}; do
    DOCKER_ENVS="${DOCKER_ENVS} -e $var=${!var}"
  done
}

docker_run() {
  DAEMON=$1
  docker run -d --name ${DAEMON} --net=host \
    -v ${HADOOP_LOG_DIR}:${HADOOP_LOG_DIR} \
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
