#!/usr/bin/env bash

BASEDIR=$(dirname "$0")
source $BASEDIR/../lib/util/util.sh
source ../lib/util/util.sh 2>/dev/null # for IDE code completion

usageMsg="ORG=<org name> ORDERER_NAME=<orderer instance name> $0"
exampleMsg="ORG=org1 ORDERER_NAME=raft0 $0"


: ${ORG:=org1}
: ${DOMAIN:=example.com}
: ${ORDERER_NAME:=raft0}
: ${DOCKER_COMPOSE_ORDERER_ARGS:=-f docker-compose-orderer.yaml}

COMPOSE_PROJECT_NAME=${ORDERER_NAME}.${DOMAIN} ORDERER_GENESIS_PROFILE=RaftOrdererGenesis docker-compose ${DOCKER_COMPOSE_ORDERER_ARGS} run -d post-install www.orderer 2>/dev/null

