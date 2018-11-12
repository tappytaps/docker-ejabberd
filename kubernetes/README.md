## Ejabberd + Kubernetes

After some googling around, I scratched my head for why there isn't any documented steps to get Ejabberd working with K8s. For that reason after some sweeting, I was abled to setup those two together quite easily. Thanks to the awesome rroemhild/ejabberd docker image and all the scripts already created around that image.

Because Kubernetes needs the image pre-built with the scripts and modification I made. I built a different image available as ccpereira/ejabberd-k8s:0.0.1

I would if approved, suggest rroemhild to later add that to the main branch.

# New environment variable:
````
EJABBERD_AUTO_JOIN_CLUSTER: true/false
````

# New script

I changed the script from the docker-compose-cluster example:

- 100_ejabberd_join_cluster.sh

Some other changes:
- base_functions.sh
- functions.sh
- run.sh

There is probably a better ways to set them together. And quite frankly, I'm not an expert on either one, but I thought, maybe someone won't waste time researching all over again, and will improve that implementation instead. So stick with me please.

## Step 1 - The environment

For that implementation to work, you have to setup a environment with kubernetes and switch the Kube-dns to CoreDns - Here you will find out how: https://kubernetes.io/docs/tasks/administer-cluster/coredns/

The reason I switched kube-dns to Coredns was that it would make things easier and I wouldn't need to setup a service discovery. I will discuss the details on my coredns setup below.

# Prerequisites:


* Kubernetes 1.11+
* CoreDns -  Install the CoreDns  - [Here is how](https://github.com/coredns/deployment/tree/master/kubernetes)


## Step 2 - Kubernetes Manifests

Firstly, there are different ways to deploy a service on Kubernetes. Here I'm using a Statefulset because of its predictable behavior. If you deploy an app with a Statefulset, as you scale up the ejabberd nodes, each ejabberd node will always have the following variation <ERLANG_NODE>@<PodHostName>.

E.g: A cluster with 3 nodes  will be:


* ERLANG_NODE: ejabberd-k8s

- Pod 1: ejabberd-k8s@pod-0 (it's not a master, but lets call that the master)
- Pod 2: ejabberd-k8s@pod-1
- Pod 3: ejabberd-k8s@pod-2


So lets see how will all the kubernetes manifests look like in the end:

We need three manifests for our ejabberd cluster and one for the Coredns config


# The StatefulSet manifest

````
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: chat # the host will be base on that name chat-0, chat-1, chat-2 as you scaleup the cluster.
spec:
  selector:
    matchLabels:
      app: xmpp # has to match .spec.template.metadata.labels
  serviceName: "xmpp-internal-svc" # has to match the headless-service name - the hostname will be ejabberd-{nodeNumber}.xmppservice
  replicas: 3 # The number of nodes to create
  template:
    metadata:
      labels:
        app: xmpp # has to match .spec.selector.matchLabels
    spec:
      terminationGracePeriodSeconds: 20
      containers:
      #Conteiner environment
      - env:
         #Ejabberd server settings
         #That variable will allow the nodes to join the cluster automatically
        - name: EJABBERD_AUTO_JOIN_CLUSTER
          value: "true"
        - name: EJABBERD_SKIP_MODULES_UPDATE
          value: "true"
        - name: EJABBERD_LOGLEVEL
          value: "4"
        - name: EJABBERD_S2S_SSL
          value: "true"
        - name: EJABBERD_STARTTLS
          value: "true"
        - name: EJABBERD_USER
          value: "ejabberd"
        - name: ERLANG_NODE
          value: "ejabberd-k8s"
        - name: ERLANG_COOKIE
          value: DOYOULIKEIT
        name: ejabberd-node
        image: ccpereira/ejabberd-k8s:0.0.1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5222
        - containerPort: 5269
        - containerPort: 5280
        - containerPort: 4369
        - containerPort: 4200
        - containerPort: 4201
        - containerPort: 4202
        - containerPort: 4203
        - containerPort: 4204
        - containerPort: 4205
        - containerPort: 4206
        - containerPort: 4207
        - containerPort: 4208
        - containerPort: 4209
        - containerPort: 4210
        resources: {}
      restartPolicy: Always

````

# The Headless Service:

The information regarding a headless service can be found [here](https://kubernetes.io/docs/concepts/services-networking/service/)

The pod's name + the headless service's name will be the hostname that we need to compose our cluster:

````
chat-0.xmpp-internal-svc
chat-1.xmpp-internal-svc
chat-1.xmpp-internal-svc

apiVersion: v1
kind: Service
metadata:
  name: xmpp-internal-svc # That name will be part of the pods' name.
  labels:
    app: xmpp
spec:
  ports:
  - name: c2s
    port: 1234
  clusterIP: None
  selector:
    app: xmpp

````
# The external service:

That service will expose the port 5222 to the clients to connect our ejabberd cluster.

````
apiVersion: v1
kind: Service
metadata:
  annotations:
  labels:
    app: xmpp
  name: xmpp-external-svc # that service will expose the 5222 port to external connections.
spec:
  type: NodePort
  selector:
    app: xmpp
  ports:
  - name: c2s
    port: 5222
    targetPort: 5222
    nodePort: 30395
  - name: admin
    port: 5280
    targetPort: 5280
    nodePort: 30396
status:
  loadBalancer: {}
````


## Step 3 - CoreDNS

The folder coredns has the manifest coredns-deployment.yaml that will setup the coredns on our cluster.

before deploy we will need to modify the CoreFile section on the ConfigMap.

Pods will always have a predictable variation of it's name with Statefulset, so leveraging the coredns "rewrite" feature, we can quite easily discovery each ejabberd node. Check out the lines that starts with 'rewrite'. My implementation won't have more that 10 ejabberd nodes, that is quite enough for now. Checkout the CoreDNS rewrite [documentation](https://github.com/coredns/coredns/tree/master/plugin/rewrite)   you can user regex to improve those rules, most probably just a line will be enough.

````
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        rewrite name chat-0 chat-0.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-1 chat-1.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-2 chat-2.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-3 chat-3.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-5 chat-4.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-5 chat-5.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-6 chat-6.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-7 chat-7.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-8 chat-8.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-9 chat-9.xmpp-internal-svc.default.svc.cluster.local
        rewrite name chat-10 chat-10.xmpp-internal-svc.default.svc.cluster.local
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
````

What this CoreDns config does? If we call  ejabberdctl join_cluster ejabberd-k8s@pod-0 for any ejabberd node, it will redirect to the service where that host(pod) is located and we will have the node joining the ejabberd cluster.


## Step 4 - Deploy the cluster

If you have all setup. Just a few commands will be enough to have a cluster up and running:

````
1). Apply the coredns config:
$kubectl apply -f /path/to/coredns-configmap.yaml

2). Apply the services and headeless services
$kubectl apply -f /path/to/headless-service.yaml
$kubectl apply -f /path/to/ejabberd-service.yaml

3). Deploy the cluster
$kubectl apply -f /path/to/statefulset.yaml


Step 5 - Check cluster status

$kubectl exec -it chat-0 ejabberdctl list_cluster
'ejabberd-k8s@chat-1'
'ejabberd-k8s@chat-0'

$kubectl exec -it chat-0 ejabberdctl list_cluster
'ejabberd-k8s@chat-2'
'ejabberd-k8s@chat-1'
'ejabberd-k8s@chat-0'
````

# Happy coding!
