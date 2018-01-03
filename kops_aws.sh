#!/bin/sh

#To run this you need a few things:
# 1) an AWS account
# 2) user in AWS account (go to IAM menu and make one) 
# 2a) Follow this: https://github.com/kubernetes/kops/blob/master/docs/aws.md#setup-your-environment
# 3) DOnt go too crazy, just need the user, S3 bucket and route 53.

###### Setting Variables for your AWS
#your domain like omg.com
$your_domain=

#bucket name like kops.omg.com
$your_s3_bucket=

##### DONE Setting Variables

echo "### installing kops 1.8 ###"
wget -q https://github.com/kubernetes/kops/releases/download/1.8.0/kops-linux-amd64
chmod +x kops-linux-amd64
mv kops-linux-amd64 kops

./kops version

export KOPS_STATE_STORE=s3://$your_s3_bucket

echo
echo "###################################"
echo
echo "Enter unique cluster name"
read clustername
echo
echo "###################################"
echo

#the real workdog
#./kops create cluster --zones=us-east-1a,us-east-1b,us-east-1c --node-count=5 $clustername.$your_domain --yes
kops create cluster \
--name="$clustername.$your_domain" \
--master-zones  us-east-1a,us-east-1b,us-east-1c \
--zones us-east-1a,us-east-1b,us-east-1c \
--node-count 5 \
--state s3://$your_s3_bucket \
--yes

echo
echo "###################################"
echo
#wait 5 minutes for things to happen
echo waiting about 5 minutes to check if this cake is ready to eat... lets update kubectl in the meantime
echo
echo "###################################"
echo

#### Installs new kubectl - not needed
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
echo
./kubectl version

sleep 300

#kops validate cluster loop
while [ 1 ]; do
    ./kops validate cluster && break || sleep 30
done;

### Installing dashboard and monitoring
#./kubectl create -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/monitoring-standalone/v1.7.0.yaml
# this guy works ++> ./kubectl create -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.6.3.yaml
# not working => ./kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
#./kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

./kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
./kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/grafana.yaml
./kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml
./kubectl create -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.6.3.yaml

### Lets deploy this init demo: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-initialization/
./kubectl create -f https://k8s.io/docs/tasks/configure-pod-container/init-containers.yaml

### Below is some QOS testing for different levels of performance/uptime/service
### https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/
./kubectl create namespace qos-namespace
./kubectl create -f https://k8s.io/docs/tasks/configure-pod-container/qos-pod.yaml --namespace=qos-namespace
./kubectl create -f https://k8s.io/docs/tasks/configure-pod-container/qos-pod-2.yaml --namespace=qos-namespace
./kubectl create -f https://k8s.io/docs/tasks/configure-pod-container/qos-pod-3.yaml --namespace=qos-namespace
./kubectl create -f https://k8s.io/docs/tasks/configure-pod-container/qos-pod-4.yaml --namespace=qos-namespace


echo
echo "###################################"
echo
echo "Go here: https://api."$clustername".soups.science/ui"
echo
echo "user: admin"
echo
#Decrypting Admin password for dashboard
./kubectl config view --minify | grep password
echo
echo "##################################"
echo
./kubectl cluster-info

###Create teh delete script
#kops delete cluster <clustername>.soups.science --yes

echo "#!/bin/sh
export KOPS_STATE_STORE=s3://kops.soups.science
./kops delete cluster $clustername.soups.science --yes
rm delete.$clustername.sh
" > delete.$clustername.sh
