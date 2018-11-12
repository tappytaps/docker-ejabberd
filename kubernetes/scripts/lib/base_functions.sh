is_set() {
    local var=$1

    [[ -n $var ]]
}


is_zero() {
    local var=$1

    [[ -z $var ]]
}


file_exist() {
    local file=$1

    [[ -e $file ]]
}


is_true() {
    local var=${1,,}
    local choices=("yes" "1" "y" "true")
    for ((i=0;i < ${#choices[@]};i++)) {
        [[ "${choices[i]}" == $var ]] && return 0
    }
    return 1
}


# overwrite this function to get hostname from other sources
# like dns or etcd
get_nodename() {
    echo ${HOSTNAME}
}


join_cluster() {
    local cluster_node=$1

    is_zero ${cluster_node} \
        && exit 0

    echo "Join cluster..."

    local erlang_node_name=${ERLANG_NODE%@*}
    local erlang_cluster_node="${erlang_node_name}@${cluster_node}"

    response=$(${EJABBERDCTL} ping ${erlang_cluster_node})
    while [ "$response" != "pong" ]; do
        echo "Waiting for ${erlang_cluster_node}..."
        sleep 2
        response=$(${EJABBERDCTL} ping ${erlang_cluster_node})
    done

    echo "Join cluster at ${erlang_cluster_node}... "
    NO_WARNINGS=true ${EJABBERDCTL} join_cluster $erlang_cluster_node

    if [ $? -eq 0 ]; then
        touch ${CLUSTER_NODE_FILE}
    else
        echo "cloud not join cluster"
        exit 1
    fi
}

join_k8s_cluster() {
    local cluster_node=$1

    is_zero ${cluster_node} \
        && exit 0

    echo "Host ${HOSTNAME} is gonna try to join the cluster..."

    local IN=${HOSTNAME}

    local domain=($(echo $IN | tr "." "\n"))

    local name=($(echo ${domain[0]} | tr "-" "\n"))

    local n=-1

    if [ ${name[1]} == 0 ]; then

      echo "Server is the Master waiting others nodes"
      exit 0
    fi

    while [ $n -le 5 ]
    do
	      (( n++ ))
      	if [ ${name[1]} == $n ]
      	then
      		echo "That is the current server: "${HOSTNAME}
      		continue
      	fi

	       local nextServer=${name[0]}-$n

      	echo "Trying to connect the node: $nextServer "

      	local erlang_node_name=${ERLANG_NODE%@*}
        local erlang_cluster_node="${erlang_node_name}@${nextServer}"

	      response=$(${EJABBERDCTL} ping ${erlang_cluster_node})

	      if [ "$response" == "pong" ]; then

        		delay=$(( ${name[1]} * 10 ))
        		echo "Joinning cluster at ${erlang_cluster_node}  with a  ${delay} sencods dalay ... "

        		#delay the request for some seconds to avoid multiples nodes joinning at the same time
        		#according with the node order
        		#that only works ond the stateful set setup on kubernetes.
        		sleep ${delay}

        		NO_WARNINGS=true ${EJABBERDCTL} join_cluster $erlang_cluster_node

        		if [ $? -eq 0 ]; then
                		touch ${CLUSTER_NODE_FILE}
        			      break
            else
                		echo "could not join the cluster"
            fi
      	else
      	  sleep 4
      	fi
  done
}
