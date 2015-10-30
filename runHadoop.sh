#!/bin/bash

# Customized hadoop configuration
: ${CONF_NAMENODE:=localhost}
: ${CONF_RESOURCEMANAGER:=localhost}
: ${CONF_DFS_REPLICATION:=1}

# Change with caution
: ${HADOOP_DOCKER_IMAGE:=ading1977/hadoop}
: ${HADOOP_DOCKER_IMAGE_TAG:=latest}
: ${HADOOP_PREFIX:=/opt/hadoop}
: ${HADOOP_LOG_DIR:=$HADOOP_PREFIX/logs}
: ${HADOOP_CONF_DIR:=$HADOOP_PREFIX/etc/hadoop}
: ${HADOOP_DATA_DIR:=/var/lib/hadoop}
: ${ZOOKEEPER_DATA_DIR:=/var/lib/zookeeper}

docker_hadoop_error() {
  echo "$*" 1>&2
}

docker_hadoop_usage() {
  echo "Usage: runHadoop.sh (namenode | datanode | resourcemanager | nodemanager)"
}

docker_hadoop_upgrade_image() {
  local IMAGE=${HADOOP_DOCKER_IMAGE}:${HADOOP_DOCKER_IMAGE_TAG}
  local CONTAINER_ID=$(docker ps -a | grep $IMAGE | grep $DAEMON | awk '{print $1}')
  local OLD_IMAGE_ID=$(docker inspect --format "{{.Id}}" $IMAGE)
  # Pull the latest image if available
  docker pull $IMAGE
  local CURRENT_IMAGE_ID=$(docker inspect --format "{{.Id}}" $IMAGE)
  # Does the container exist
  if [ -z $CONTAINER_ID ]; then
    if [ -n "$OLD_IMAGE_ID" ] && [ "$CURRENT_IMAGE_ID" != "$OLD_IMAGE_ID" ]; then
      docker tag $OLD_IMAGE_ID ${HADOOP_DOCKER_IMAGE}:$(date +"%F-%s")
    fi
    return 2
  fi

  # CONTAINER_ID is not null
  CURRENT_IMAGE_ID=$(docker inspect --format "{{.Image}}" $CONTAINER_ID)
  local IS_RUNNING=$(docker inspect --format "{{.State.Running}}" $CONTAINER_ID)
  local LATEST_IMAGE_ID=`docker inspect --format "{{.Id}}" $IMAGE`
  echo "Current image:" $CURRENT_IMAGE_ID
  echo "Latest image:" $LATEST_IMAGE_ID
  if [ "$CURRENT_IMAGE_ID" != "$LATEST_IMAGE_ID" ]; then
    echo "upgrading $DAEMON image"
    docker tag $CURRENT_IMAGE_ID ${HADOOP_DOCKER_IMAGE}:$(date +"%F-%s")
    docker stop $CONTAINER_ID
    docker rm -f -v $CONTAINER_ID
    return 2
  elif [ ${IS_RUNNING} = false ]; then
    echo "$DAEMON is not running"
    return 1
  else
    echo "$DAEMON is running, and the image is up to date"
    return 0
  fi
}

docker_hadoop_expand_env() {
  DOCKER_ENVS=""
  for var in  ${!CONF_*}; do
    DOCKER_ENVS="${DOCKER_ENVS} -e $var=${!var}"
  done
}

docker_run_bash() {
  local IMAGE=${HADOOP_DOCKER_IMAGE}:${HADOOP_DOCKER_IMAGE_TAG}
  docker run -it --rm --net=host \
    -v ${HADOOP_DATA_DIR}:${HADOOP_DATA_DIR} \
    -v ${HADOOP_CONF_DIR}:${HADOOP_CONF_DIR} \
    -v ${HADOOP_LOG_DIR}:${HADOOP_LOG_DIR} \
    -v ${ZOOKEEPER_DATA_DIR}:${ZOOKEEPER_DATA_DIR} \
    ${DOCKER_ENVS} \
    ${IMAGE}
}

docker_run_daemon() {

  DAEMON=$1

  docker_hadoop_upgrade_image

  local rval=$?
  if [ $rval -eq 0 ]; then
    return 0
  elif [ $rval -eq 1 ]; then
    docker start ${DAEMON}
    return $?
  fi

  mkdir -p ${HADOOP_DATA_DIR}
  mkdir -p ${HADOOP_CONF_DIR}
  mkdir -p ${HADOOP_LOG_DIR}

  local IMAGE=${HADOOP_DOCKER_IMAGE}:${HADOOP_DOCKER_IMAGE_TAG}
  docker run -d --restart=always --name ${DAEMON} --net=host \
    -v ${HADOOP_DATA_DIR}:${HADOOP_DATA_DIR} \
    -v ${HADOOP_CONF_DIR}:${HADOOP_CONF_DIR} \
    -v ${HADOOP_LOG_DIR}:${HADOOP_LOG_DIR} \
    -v ${ZOOKEEPER_DATA_DIR}:${ZOOKEEPER_DATA_DIR} \
    ${DOCKER_ENVS} \
    ${IMAGE} $DAEMON
  
  return $?
}

docker_hadoop_expand_env

if [[ $# = 0 ]]; then
  docker_run_bash
  exit 0
fi

SERVICE=$1
case ${SERVICE} in
  namenode)
    docker_run_daemon namenode
  ;;
  datanode)
    docker_run_daemon datanode
  ;;
  resourcemanager)
    docker_run_daemon resourcemanager
    docker_run_daemon proxyserver
  ;;
  nodemanager)
    docker_run_daemon nodemanager
  ;;
  zookeeper)
    docker_run_daemon zookeeper
  ;;
  help)
    docker_hadoop_usage
    exit 0
  ;;
  *)
    docker_run_bash
  ;;
esac
