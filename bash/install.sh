#!/bin/bash

# Azure Default Information
AKS_SUBSCRIPTION=$(az account list --query [?isDefault].id -o tsv); # Select Default subscription
AKS_USER_ADMIN=$(az ad signed-in-user show --query objectId -o tsv); # Get object Id from user running the script

# Azure Active Directory Information
AKS_ADMIN_GROUP="AZB_ADMIN"; # Azure AD AZB Admin Group
AKS_USER_GROUP="AZB_USER"; # Azure AD AZB User Group to assign "Azure Kubernetes Service Cluster User Role"

# Default Azure Resource Information
AKS_RESOURCE_GROUP="aks-azb-rg"
AKS_LOCATION="eastus2"
AKS_VNET_NAME="aks-vnet"
AKS_VNET_PREFIX="10.1.0.0/16"
AKS_SUBNET_NAME="aks-subnet"
AKS_SUBNET_PREFIX="10.1.0.0/24"
AKS_NAME="aks-azb"
AKS_VM_SIZE="Standard_B2ms"
AKS_NODE_COUNT="1"
AKS_LB_SKU="basic"

# AZB Default Information
AKS_POD_IDENTITY_NAME="azb-identity"
AKS_NAMESPACE="azb-ns"

# FIX BASH FOR WINDOWS 
if [[ $OSTYPE = "msys" ]]; 
then
    export MSYS_NO_PATHCONV=1
fi

while getopts r:l:v:e:s:t:n:s:c:b flag
do
    case "${flag}" in
        r) AKS_RESOURCE_GROUP=$OPTARG;;
        l) AKS_LOCATION=$OPTARG;;
        v) AKS_VNET_NAME=$OPTARG;;
        e) AKS_VNET_PREFIX=$OPTARG;;
        s) AKS_SUBNET_NAME=$OPTARG;;
        t) AKS_SUBNET_PREFIX=$OPTARG;;
        n) AKS_NAME=$OPTARG;;
        s) AKS_VM_SIZE=$OPTARG;;
        c) AKS_NODE_COUNT=$OPTARG;;
        b) AKS_LB_SKU=$OPTARG;;
        o) AKS_ADMIN_GROUP=$OPTARG;;
        u) AKS_USER_GROUP=$OPTARG;;
        i) AKS_POD_IDENTITY_NAME=$OPTARG;;
        p) AKS_NAMESPACE=$OPTARG;;
        \?) echo "-$OPTARG is not a valid parameter";exit;
    esac
done

echo "Using Parameters:"
echo "AKS_SUBSCRIPTION: $AKS_SUBSCRIPTION"
echo "AKS_USER_ADMIN: $(az ad signed-in-user show --query userPrincipalName -o tsv)"
echo "AKS_ADMIN_GROUP: $AKS_ADMIN_GROUP"
echo "AKS_USER_GROUP: $AKS_USER_GROUP"
echo "AKS_RESOURCE_GROUP: $AKS_RESOURCE_GROUP"
echo "AKS_LOCATION: $AKS_LOCATION"
echo "AKS_VNET_NAME: $AKS_VNET_NAME"
echo "AKS_VNET_PREFIX: $AKS_VNET_PREFIX"
echo "AKS_SUBNET_NAME: $AKS_SUBNET_NAME"
echo "AKS_SUBNET_PREFIX: $AKS_SUBNET_PREFIX"
echo "AKS_NAME: $AKS_NAME"
echo "AKS_VM_SIZE: $AKS_VM_SIZE"
echo "AKS_NODE_COUNT: $AKS_NODE_COUNT"
echo "AKS_LB_SKU: $AKS_LB_SKU"
echo "AKS_POD_IDENTITY_NAME: $AKS_POD_IDENTITY_NAME"
echo "AKS_NAMESPACE: $AKS_NAMESPACE"

read -p "Continue (y/n)?" CONT
if [ "$CONT" = "y" ]; then
  echo "Creating cluster...";
else
  exit;
fi

function install_az_extension {
    az extension add --name aks-preview
    az extension update --name aks-preview;
}

function check_az_cli {
    echo "Checking Azure CLI";
    if ! command -v az &> /dev/null ;
    then
        echo "Azure CLI could not be found";
        exit
    else
        echo "Azure CLI installed";
        az version;
        az account set --subscription $AKS_SUBSCRIPTION;
    fi
}

function check_aks_admin_group {
    echo "Checking AD Group - $AKS_ADMIN_GROUP";
    if (az ad group show --group $AKS_ADMIN_GROUP) ;
    then
        echo "$AKS_ADMIN_GROUP exists";
    else
        az ad group create --display-name $AKS_ADMIN_GROUP --mail-nickname $AKS_ADMIN_GROUP;
        az ad group owner add --group $AKS_ADMIN_GROUP --owner-object-id $AKS_USER_ADMIN
    fi
}

function check_aks_user_group {
    echo "Checking AD Group - $AKS_USER_GROUP";
    if (az ad group show --group $AKS_USER_GROUP) ;
    then
        echo "$AKS_USER_GROUP exists";
    else
        az ad group create --display-name $AKS_USER_GROUP --mail-nickname $AKS_USER_GROUP;
        az ad group owner add --group $AKS_USER_GROUP --owner-object-id $AKS_USER_ADMIN
    fi
}

function check_aks_admin_user {
    echo "Checking AD Group Membership - $AKS_USER_ADMIN";
    AZ_AD_GROUP_EXIST=$(az ad group member check --group $AKS_ADMIN_GROUP --member-id $AKS_USER_ADMIN --query 'value');
    if [[ $AZ_AD_GROUP_EXIST = "false" ]] ;
    then
        echo "Adding $AKS_USER_ADMIN in group $AKS_ADMIN_GROUP ";
        az ad group member add --group  $AKS_ADMIN_GROUP --member-id $AKS_USER_ADMIN;
    else
      echo "$AKS_USER_ADMIN exists in group $AKS_ADMIN_GROUP ";
    fi
}

function check_resource_group {
    echo "Checking Resource Group - $AKS_RESOURCE_GROUP";
    AKS_RESOURCE_GROUP_EXIST=$(az group exists --name $AKS_RESOURCE_GROUP );
    if [[ "$AKS_RESOURCE_GROUP_EXIST" = "false" ]] ;
    then
        echo "Creating $AKS_RESOURCE_GROUP in $AKS_LOCATION ";
        az group create --location $AKS_LOCATION --name $AKS_RESOURCE_GROUP;
    else
      echo "$AKS_RESOURCE_GROUP alredy exists";
    fi
}

function check_virtual_network {
    echo "Checking Virtual Network - $AKS_VNET_NAME";
    if (az network vnet show -g $AKS_RESOURCE_GROUP -n $AKS_VNET_NAME) ;
    then
        echo "$AKS_VNET_NAME already exists";
    else
      echo "Creating $AKS_VNET_NAME ";
        az network vnet create -g $AKS_RESOURCE_GROUP -n $AKS_VNET_NAME --address-prefix $AKS_VNET_PREFIX --subnet-name $AKS_SUBNET_NAME --subnet-prefix $AKS_SUBNET_PREFIX --location $AKS_LOCATION
    fi
}

function check_aks {
    echo "Checking AKS - $AKS_NAME";
    if (az aks show --name  $AKS_NAME --resource-group $AKS_RESOURCE_GROUP ) ;
    then
        echo "$AKS_NAME already exists";
    else
        echo "Creating new AKS Server - $AKS_NAME";
        AKS_ADMIN_GROUP_ID=$(az ad group show --group $AKS_ADMIN_GROUP --query objectId -o tsv) ;
        echo "AKS Admin Group Id $AKS_ADMIN_GROUP_ID"
        AKS_SUBNET_ID=$(az network vnet show -g $AKS_RESOURCE_GROUP -n $AKS_VNET_NAME --query subnets[0].id -o tsv);
        echo "AKS Subnet Id $AKS_SUBNET_ID"
        az aks create --name $AKS_NAME --resource-group $AKS_RESOURCE_GROUP --location $AKS_LOCATION --node-vm-size $AKS_VM_SIZE --node-count $AKS_NODE_COUNT --aad-admin-group-object-ids $AKS_ADMIN_GROUP_ID --vnet-subnet-id $AKS_SUBNET_ID --load-balancer-sku $AKS_LB_SKU --enable-aad --enable-azure-rbac --enable-pod-identity --network-plugin "azure" --generate-ssh-keys --enable-managed-identity; 
        AKS_CLUSTER_ID=$(az aks show --name $AKS_NAME --resource-group $AKS_RESOURCE_GROUP --query id -o tsv);
        AKS_USER_GROUP_ID=$(az ad group show --group $AKS_USER_GROUP --query objectId -o tsv) ;
        echo "Updating Azure Kubernetes Service Cluster User Role to $AKS_USER_GROUP";
        az role assignment create --role "Azure Kubernetes Service Cluster User Role" --assignee $AKS_USER_GROUP_ID --scope $AKS_CLUSTER_ID;
    fi
}

function check_pod_identity {
    echo "Checking Pod Identity - $AKS_POD_IDENTITY_NAME";
    if (az identity show -n $AKS_POD_IDENTITY_NAME -g $AKS_RESOURCE_GROUP ) ;
    then
        echo "Pod Identity $AKS_NAME already exists";
    else
        echo "Creating new Pod Identity - $AKS_NAME";
        az identity create -g $AKS_RESOURCE_GROUP -n $AKS_POD_IDENTITY_NAME;
        POD_IDENTITY_ID=$(az identity show --name $AKS_POD_IDENTITY_NAME --resource-group $AKS_RESOURCE_GROUP -o tsv --query principalId);
        
        # Wait sometime before adding to user group
        sleep 45  # Fix Resource 'XXXXXX' does not exist or one of its queried reference-property objects are not present.
        az ad group member add --group $AKS_USER_GROUP --member-id $POD_IDENTITY_ID;
    fi
}

function connect_aks {
    echo "Conecting to new cluster..."
    az aks install-cli
    az aks get-credentials --resource-group $AKS_RESOURCE_GROUP --name $AKS_NAME --admin;
}

function setup_aks {
    kubectl create namespace $AKS_NAMESPACE;
    AKS_USER_GROUP_ID=$(az ad group show --group $AKS_USER_GROUP --query objectId -o tsv) ;
    echo "Updating Azure Kubernetes Service RBAC Writer to $AKS_USER_GROUP";
    az role assignment create --role "Azure Kubernetes Service RBAC Writer" --assignee $AKS_USER_GROUP_ID --scope "/subscriptions/$AKS_SUBSCRIPTION/resourcegroups/$AKS_RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$AKS_NAME/namespaces/$AKS_NAMESPACE";
    echo "Creating Pod Identity for Namespace $AKS_NAMESPACE";
    az aks pod-identity add --resource-group $AKS_RESOURCE_GROUP --cluster-name $AKS_NAME --namespace $AKS_NAMESPACE --name $AKS_POD_IDENTITY_NAME --identity-resource-id "/subscriptions/$AKS_SUBSCRIPTION/resourceGroups/$AKS_RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$AKS_POD_IDENTITY_NAME";
}

check_az_cli
install_az_extension
check_aks_admin_group
check_aks_admin_user
check_aks_user_group
check_resource_group
check_virtual_network
check_pod_identity
check_aks
connect_aks
setup_aks

echo "Setup completed"