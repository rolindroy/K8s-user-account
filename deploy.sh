
#!/usr/bin/env bash

# r
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail


# setting script directory
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
DEFAULT_NAMESPACE=webapplication
DEFAULT_USERACCOUNT=developer
DEFAULT_CA_PATH=/etc/kubernetes/pki


RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'

if [[ -z "${KUBECONFIG}" ]] 
then
    export KUBECONFIG=~/.kube/config
fi

# namespace
read -p "Enter desired namespace for user account [$DEFAULT_NAMESPACE]: " NAMESPACE
NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
tput sgr0

echo -e "${BLUE}Creating ${ORANGE}${NAMESPACE} ${BLUE}namespace."
kubectl create namespace "$NAMESPACE"

# kubectl command
kctl() {
    kubectl "$@"
}

# user account
read -p "Enter desired useraccount name [$DEFAULT_USERACCOUNT]: " USERACCOUNT
USERACCOUNT=${USERACCOUNT:-$DEFAULT_USERACCOUNT}
tput sgr0

echo -e "${BLUE} Creating ${ORANGE}${USERACCOUNT} ${BLUE}directory."
mkdir -p ${SCRIPTDIR}/${USERACCOUNT} && cd ${USERACCOUNT}
echo -e "${BLUE} Creating ${BLUE}private key for user account${ORANGE}${USERACCOUNT}"
openssl genrsa -out ${USERACCOUNT}.key 2048 
openssl req -new -key ${USERACCOUNT}.key -out ${USERACCOUNT}.csr -subj "/CN=${USERACCOUNT} /O=${NAMESPACE}"

read -p "Enter the kubernetes CA Certs Path [$DEFAULT_CA_PATH]: " CA_PATH
CA_PATH=${CA_PATH:-$DEFAULT_CA_PATH}
tput sgr0

echo -e "${BLUE} Signing certificate with ${ORANGE}${CA_PATH}/ca.crt ${BLUE}directory."
openssl x509 -req -in ${USERACCOUNT}.csr -CA ${CA_PATH}/ca.crt -CAkey ${CA_PATH}/ca.key -CAcreateserial -out ${USERACCOUNT}.crl -days 365

# set namespace in various resources
for n in $(egrep -lir --include=*.{yaml,sh} "CUSTOM_NAMESPACE" manifests); do
  sed -i -e 's,CUSTOM_NAMESPACE,'"${NAMESPACE}"',g' ${n}
  sed -i -e 's,CUSTOM_USERNAME,'"${USERACCOUNT}"',g' ${n}
done

kctl create -f ${SCRIPTDIR}/manifests/*.yaml
kubectl config set-credentials ${USERACCOUNT} --client-certificate=${SCRIPTDIR}/${USERACCOUNT}/${USERACCOUNT}.crt \ 
    --client-key=${SCRIPTDIR}/${USERACCOUNT}/${USERACCOUNT}.key
