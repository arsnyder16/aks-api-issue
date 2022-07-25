set -e

rg=
acr=
aks=
location=northcentralus
aksVersion=1.23.8

az aks create \
  --resource-group $rg \
  --name $aks \
  --vm-set-type VirtualMachineScaleSets \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --node-osdisk-size 64 \
  --node-osdisk-type Ephemeral \
  --generate-ssh-keys \
  --kubernetes-version $aksVersion \
  --load-balancer-sku standard \
  --attach-acr $acr \
  --location $location \
  --enable-managed-identity \
  --uptime-sla \
  --enable-encryption-at-host

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace ingress \
  --set controller.replicaCount=0 \
  --set controller.service.externalTrafficPolicy=Local \
  --wait

az aks get-credentials --name $aks --resource-group $rg

kubectl create namespace api-issue

# add kubectl repro workload
# should show error as kubectl client timing out after 10 seconds trying to TLS handshake
kubectl apply -f kubectl.yaml

# build simple nodejs example that uses k8s sdk
# node failures will detect any api request longer than 60 seconds and exit the pod
# but will sometimes be over 300 seconds
az acr login --name $acr
IMAGE=$acr.azurecr.io/slowrequest-node:latest
docker build -t $IMAGE .
docker push $IMAGE
sed "s/{acr}/$acr/g" node.yaml | kubectl apply -f - 

# wait for failures
kubectl get pods -n api-issue -w
