<#
.SYNOPSIS
    Creates an Azure Kubernetes Cluster, and an nginx demo deployment
.DESCRIPTION
    Creates an Azure Kubernetes Cluster, and an nginx demo deployment by automating the following steps:
    - Creates a Resource Group
    - Creates an AKS cluster
    - Applies an nginx demo deployment
    - Creates a ClusterRoleBinding to access the Kubernetes dashboard
    - Opens the Kubernetes dashboard in your default browser

.NOTES
    Assumptions:
    - Azure PowerShell module is installed: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps
    - Azure CLI is installed: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows
    - You are already logged into Azure before running this script (eg. "az login" and "Connect-AzAccount")
    - If using Cloud Shell, you've opened https://shell.azure.com/ and chosen a PowerShell shell

    Author:  Adam Rush
    Blog:    https://adamrushuk.github.io
    GitHub:  https://github.com/adamrushuk
    Twitter: @adamrushuk
#>


#region Vars
# no dashes or spaces allowed in prefix, and MUST be lowercase as some character restrictions for some resources
$uniquePrefix = "adamrushuk"

# Shouldn't need to change anything below
$aksClusterName = "$($uniquePrefix)-aks-cluster01"
$location = "eastus"
$aksResourceGroup = "akspipeline"
$aksNodeCount = 2
$latestVersion = $(az aks get-versions -l $location --query 'orchestrators[-1].orchestratorVersion' -o tsv)
#endregion Vars


#region Create resources
# Create a Resource Group
az group create --name $aksResourceGroup --location $location

# Create AKS using the latest version available
# AKS cluster name MUST be unique, eg: adamrushuk-aks-cluster01
az aks create --resource-group $aksResourceGroup --name $aksClusterName --node-count $aksNodeCount --kubernetes-version $latestVersion --enable-addons monitoring --generate-ssh-keys
#endregion Create resources


#region Validate AKS cluster
# Install kubectl locally (if required)
az aks install-cli

# Get the access credentials for the Kubernetes cluster
# Creds are merged into your current console session, eg:
#   Merged "adamrushuk-aks-cluster01" as current context in /home/adam/.kube/config
az aks get-credentials --resource-group $aksResourceGroup --name $aksClusterName

# Show k8s nodes / pods
kubectl get nodes
kubectl get pods
#endregion Validate AKS cluster


#region Deploy nginx demo
# Deploy yaml
kubectl apply -f nginxdemo.yml

# Monitor deployment
# Wait to see the EXTERNAL-IP appear, using --watch
# Use `Ctrl + C` to cancel
kubectl get service nginxdemo --watch

# Show service info
kubectl describe service nginxdemo
#endregion Deploy nginx demo


#region Kubernetes Dashboard
# Access the Kubernetes web dashboard in Azure Kubernetes Service (AKS)
# https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard

# You may need to create a ClusterRoleBinding to access the Web GUI properly
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

# Start the Kubernetes dashboard
az aks browse --resource-group $aksResourceGroup --name $aksClusterName
#endregion Kubernetes Dashboard


#region Cleanup
Write-Host "WARNING: AKS Resource Groups will now be deleted!" -ForegroundColor Yellow
Write-Host "Press CTRL + C to cancel, or..." -ForegroundColor Yellow
Pause

$resourceGroupNames = @(
    $aksResourceGroup
    "MC_$($aksResourceGroup)_$($aksClusterName)_$($location)"
    "DefaultResourceGroup-EUS"
    "NetworkWatcherRG"
)
$rgDeleteJobs = $resourceGroupNames | ForEach-Object { Remove-AzResourceGroup -Name $_ -Force -AsJob }
$rgDeleteJobs | Wait-Job
$rgDeleteJobs | Receive-Job -Keep
#endregion Cleanup
