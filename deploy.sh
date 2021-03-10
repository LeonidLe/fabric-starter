#!/usr/bin/env bash

function info() {
    echo -e "************************************************************\n\033[1;33m${1}\033[m\n************************************************************"
}

orgs=$@
first_org=${1:-org1}

DEV_MODE=${DEV_MODE}
AGENT_MODE=${AGENT_MODE}

if [ -z "${DEV_MODE}" ]; then
    HTTPS_MODE=${HTTPS_MODE-1}
    LDAP_ENABLED=${LDAP_ENABLED:-1}
    RENEW_IMAGES=${RENEW_IMAGES-1}
fi

export ORG=''
if [ -z "${AGENT_MODE}" ]; then
   source ${first_org}_env;
   export ORG=${ORG:-${first_org:-org1}}
   export DOMAIN=${DOMAIN:-example.com}
fi

export ORDERER_WWW_PORT=${ORDERER_WWW_PORT:-79}
export SERVICE_CHANNEL=${SERVICE_CHANNEL:-common}

export DOCKER_REGISTRY=${DOCKER_REGISTRY:-docker.io}
export FABRIC_VERSION=${FABRIC_VERSION:-1.4.4}
export FABRIC_STARTER_VERSION=${FABRIC_STARTER_VERSION:-baas-test}


: ${DOCKER_COMPOSE_ORDERER_ARGS:="-f docker-compose-orderer.yaml -f docker-compose-orderer-domain.yaml -f docker-compose-orderer-ports.yaml"}

docker_compose_args=${DOCKER_COMPOSE_ARGS:-"-f docker-compose.yaml -f docker-compose-couchdb.yaml -f docker-compose-ldap.yaml -f docker-compose-preload-images.yaml"}
if [ -n "${HTTPS_MODE}" ]; then # https mode
    export LDAPADMIN_HTTPS=${LDAPADMIN_HTTPS:-true}
    export DOCKER_COMPOSE_EXTRA_ARGS=${DOCKER_COMPOSE_EXTRA_ARGS:-"-f https/docker-compose-https-ports.yaml"}
else # http mode
    export LDAPADMIN_HTTPS=${LDAPADMIN_HTTPS:-false}
    export DOCKER_COMPOSE_EXTRA_ARGS=${DOCKER_COMPOSE_EXTRA_ARGS:-"-f docker-compose-dev.yaml"}
    export BOOTSTRAP_SERVICE_URL=http
fi


if [ "$DEPLOY_VERSION" == "Hyperledger Fabric 1.4.4-GOST-34" ]; then
    set -x
    export DOCKER_REGISTRY=45.12.73.98
    export FABRIC_VERSION=gost
    export FABRIC_STARTER_VERSION=gost
    export AUTH_MODE=ADMIN
    export CRYPTO_ALGORITHM=GOST
    export SIGNATURE_HASH_FAMILY=SM3

    sudo mkdir -p /etc/docker/certs.d/${DOCKER_REGISTRY}
    openssl s_client -showcerts -connect ${DOCKER_REGISTRY}:443 </dev/null 2>/dev/null|openssl x509 -outform PEM \
        | sudo tee /etc/docker/certs.d/${DOCKER_REGISTRY}/ca.crt
    set +x
fi

if [ -z "${NO_CLEAN}" ]; then
    info "Cleaning up"
    ./clean.sh all
 fi

set -x
if [[ -n "${RENEW_IMAGES}" ]]; then
    docker pull ${DOCKER_REGISTRY:-docker.io}/olegabu/fabric-tools-extended:${FABRIC_STARTER_VERSION:-latest}
    docker pull ${DOCKER_REGISTRY:-docker.io}/olegabu/fabric-starter-rest:${FABRIC_STARTER_VERSION:-latest}
fi
set +x

export COMPOSE_PROJECT_NAME=${ORG:-org1}

if [ -z "$AGENT_MODE" ]; then
    info "Start ordering service"
    ORDERER_WWW_PORT=${ORDERER_WWW_PORT} ./ordering-start.sh $ORG $DOMAIN
    sleep 5
fi

info "Create first organization ${ORG}"
set -x
BOOTSTRAP_IP=${BOOTSTRAP_IP} ENROLL_SECRET="${ENROLL_SECRET:-adminpw}"  docker-compose ${docker_compose_args} ${DOCKER_COMPOSE_EXTRA_ARGS} \
    up -d ${AGENT_MODE:+ api www.peer}
set +x

if [ -z "${AGENT_MODE}" ]; then
    docker logs -f post-install.${ORG}.${DOMAIN}

fi

sleep 2
docker ps