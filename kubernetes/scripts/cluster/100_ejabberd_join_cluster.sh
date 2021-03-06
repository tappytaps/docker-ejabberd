#!/bin/bash
set -e

source "${EJABBERD_HOME}/scripts/lib/base_config.sh"
source "${EJABBERD_HOME}/scripts/lib/config.sh"
source "${EJABBERD_HOME}/scripts/lib/base_functions.sh"
source "${EJABBERD_HOME}/scripts/lib/functions.sh"


get_cluster_node_from_dns() {
    local cluster_host=$(drill ${DOMAINNAME} \
        | grep ${DOMAINNAME} \
        | grep -v ${HOSTIP} \
        | awk '{print $5}' \
        | grep -v "^$" \
        | head -1)
    echo $(discover_dns_hostname ${cluster_host})
}


#file_exist ${FIRST_START_DONE_FILE} \
#    && exit 0

  if [[ $EJABBERD_AUTO_JOIN_CLUSTER == "true" ]];
  then
	   join_k8s_cluster $(get_cluster_node_from_dns)
  else
     echo "Join cluster automatically disabled  - set EJABBERD_AUTO_JOIN_CLUSTER = true"
  fi
exit 0
