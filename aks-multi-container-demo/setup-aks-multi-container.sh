# Set up script for Hands-on-Lab: Deploying a multi-container application to Azure Kubernetes Services
# Setting up the environment:  https://www.azuredevopslabs.com/labs/vstsextend/kubernetes/#setting-up-the-environment

# Open https://shell.azure.com/ and choose a BASH shell
# Copy/paste commands below

# Vars
# no dashes or spaces allowed in prefix, and MUST be lowercase as some character restrictions for some resources
UNIQUE_PREFIX="adamrushuk"

# Shouldn't need to change anything below
AKS_CLUSTER_NAME="${UNIQUE_PREFIX}-aks-cluster01"
ACR_NAME="${UNIQUE_PREFIX}acr01"
AKS_RESOURCE_GROUP="akshandsonlab"
LOCATION="eastus"
VERSION=$(az aks get-versions -l $LOCATION --query 'orchestrators[-1].orchestratorVersion' -o tsv)
SQL_SERVER_NAME="${UNIQUE_PREFIX}azsqlserver01"

# Create a Resource Group
az group create --name $AKS_RESOURCE_GROUP --location $LOCATION

# Create AKS using the latest version available
# AKS cluster name MUST be unique, eg: adamrushuk-aks-cluster01
az aks create --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --enable-addons monitoring --kubernetes-version $VERSION --generate-ssh-keys --location $LOCATION

# Deploy Azure Container Registry (ACR)
az acr create --resource-group $AKS_RESOURCE_GROUP --name $ACR_NAME --sku Standard --location $LOCATION


# Grant AKS-generated Service Principal access to ACR
# Get the id of the service principal configured for AKS
CLIENT_ID=$(az aks show --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)

# Get the ACR registry resource id
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $AKS_RESOURCE_GROUP --query "id" --output tsv)

# Create role assignment
az role assignment create --assignee $CLIENT_ID --role acrpull --scope $ACR_ID


# Create Azure SQL server and Database
# Create an Azure SQL server
az sql server create -l $LOCATION -g $AKS_RESOURCE_GROUP -n $SQL_SERVER_NAME -u sqladmin -p P2ssw0rd1234

# Create a database
az sql db create -g $AKS_RESOURCE_GROUP -s $SQL_SERVER_NAME -n mhcdb --service-objective S0


# Check GUI manually for some unique info
# The following components - Container Registry, Kubernetes Service, SQL Server along with SQL Database are deployed.
# Access each of these components individually and make a note of the details which will be used in Exercise 1.
# SQL database > Server name, eg:
# adamrushukazsqlserver01.database.windows.net

# resource group > container registry > Login server name, eg:
# adamrushukacr01.azurecr.io


# Follow steps to update the Build and Release pipelines

# Get the access credentials for the Kubernetes cluster
# Creds are merged into your current console session, eg:
# Merged "adamrushuk-aks-cluster01" as current context in /home/adam/.kube/config
az aks get-credentials --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Show k8s nodes / pods
kubectl get nodes
kubectl get pods

# Wait to see the EXTERNAL-IP appear, using --watch
# Use `Ctrl + C` to cancel
kubectl get service mhc-front --watch


# Access the Kubernetes web dashboard in Azure Kubernetes Service (AKS)
https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard

# You may need to create a ClusterRoleBinding to access the Web GUI properly
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

# Start the Kubernetes dashboard
az aks browse --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
