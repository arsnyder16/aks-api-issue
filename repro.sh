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

az aks get-credentials --name $aks --resource-group $rg

kubectl create namespace api-issue

# add kubectl repro workload
# should show error as kubectl client timing out after 10 seconds trying to TLS handshake
kubectl apply -n api-issue -f kubectl.yaml

# build simple nodejs example that uses k8s sdk
# node failures will detect any api request longer than 60 seconds and exit the pod
# but will sometimes be over 300 seconds
az acr login --name $acr
IMAGE=$acr.azurecr.io/slowrequest-node:latest
docker build -t $IMAGE .
docker push $IMAGE
sed "s/{acr}/$acr/g" node.yaml | kubectl apply -n api-issue -f - 

# at this point these jobs will run fine, i have run them for days without issue. but the next step will start to cause intermittent issues 

# does not need to point at anything all that seems required is that a public ingress ip address is created
# even if this points to something valid it make no difference
# intermittent issues in the jobs created above will start appearing
kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: api-issue
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: myapp
EOF

# wait for failures
kubectl get pods -n api-issue -w
