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

docker_hadoop_error() {
  echo "$*" 1>&2
}

docker_hadoop_usage() {
  echo "Usage: runHadoop.sh (namenode | datanode | resourcemanager | nodemanager)"
}

docker_hadoop_upgrade_image() {
  local IMAGE=${HADOOP_DOCKER_IMAGE}:${HADOOP_DOCKER_IMAGE_TAG}
  local CID=$(docker ps -a | grep $IMAGE | grep $DAEMON | awk '{print $1}')

  # Pull the latest image if available
  docker pull $IMAGE

  # Does the container exist
  if [ -z $CID ]; then
    return 2
  fi

  local RUNNING=$(docker inspect --format "{{.State.Running}}" $CID)
  local CURRENT=`docker inspect --format "{{.Image}}" $CID`
  local LATEST=`docker inspect --format "{{.Id}}" $IMAGE`
  echo "Current image:" $CURRENT
  echo "Latest image:" $LATEST
  if [ "$CURRENT" != "$LATEST" ]; then
    echo "upgrading $DAEMON image"
    docker tag $CURRENT ${HADOOP_DOCKER_IMAGE}:$(date +"%F-%s")
    docker stop $CID
    docker rm -f -v $CID
    return 2
  elif [ ${RUNNING} = false ]; then
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

docker_hadoop_create_data_volume() {
  DATA_VOLUME_CONTAINER=hadoop_data_volume
  local IMAGE=${HADOOP_DOCKER_IMAGE}
  local DATA_IMAGE=${HADOOP_DOCKER_IMAGE}:data
  local CID=$(docker ps -a | grep $DATA_IMAGE | awk '{print $1}')
  if [ -z $CID ]; then
    local IID=$(docker images | grep $IMAGE | awk '{print $3}')
    if [ -z $IID ]; then
      docker pull $IMAGE
      IID=$(docker images | grep $IMAGE | awk '{print $3}')
      if [ -z $IID ]; then
        return 1
      fi
    fi
    echo "Creating data volume container" 
    docker tag $IID ${DATA_IMAGE}
    docker create \
      -v ${HADOOP_CONF_DIR} \
      -v ${HADOOP_DATA_DIR} \
      --name ${DATA_VOLUME_CONTAINER} \
      ${DATA_IMAGE}
  fi
}

docker_run() {

  docker_hadoop_upgrade_image

  local rval=$?
  if [ $rval -eq 0 ]; then
    return 0
  elif [ $rval -eq 1 ]; then
    docker start ${DAEMON}
    return $?
  fi

  local IMAGE=${HADOOP_DOCKER_IMAGE}:${HADOOP_DOCKER_IMAGE_TAG}
  docker run -d --name ${DAEMON} --net=host \
    --volumes-from ${DATA_VOLUME_CONTAINER} \
    -v ${HADOOP_LOG_DIR}:${HADOOP_LOG_DIR} \
    ${DOCKER_ENVS} \
    ${IMAGE} ${DAEMON}
  
  return $?
}

if [[ $# = 0 ]]; then
  docker_hadoop_usage
  exit 1
fi

docker_hadoop_expand_env

docker_hadoop_create_data_volume
if [ $? -ne 0 ]; then
  echo "Failed to create hadoop data volume container"
  exit 1
fi

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
