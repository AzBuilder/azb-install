# azb-install

## Requirements

In order to run the installation script you will need to install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

## Cluster creation
To create the cluster use the following commands:

```bash
git clone git@github.com:AzBuilder/azb-install.git
cd bash
./install.sh
```

## Default Parameters

This values are used by default when running the script:

| Value              | Description                |
| ------------------ | -------------              |
| AKS_SUBSCRIPTION   | Default Azure Subscription |
| AKS_USER_ADMIN     | Azure CLI User             |

> You can change this behaviour modifying the installation script

## Supported Flags

The following flags can be used when running the installation script:

| Parameter  | Description           | Default Value |
| :----:     | --------------------  | ------------- |
|r           | AKS_RESOURCE_GROUP    | aks-azb-rg    |
|l           | AKS_LOCATION          | eastus2       |
|v           | AKS_VNET_NAME         | aks-vnet      |
|e           | AKS_VNET_PREFIX       | 10.1.0.0/16   |
|s           | AKS_SUBNET_NAME       | aks-subnet    |
|t           | AKS_SUBNET_PREFIX     | 10.1.0.0/24   |
|n           | AKS_NAME              | aks-azb       |
|s           | AKS_VM_SIZE           | Standard_B2ms |
|c           | AKS_NODE_COUNT        | 1             |
|b           | AKS_LB_SKU            | basic         |
|i           | AKS_POD_IDENTITY_NAME | azb-identity  |
|p           | AKS_NAMESPACE         | azb-ns        |

Example: 
```bash
./install.sh -r custom-rg -l southcentralus
```

## Test Installation

In order to check the default installation create a new pod using demo.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels:
    aadpodidbinding: azb-identity
spec:
  containers:
  - name: azcli
    image: mcr.microsoft.com/azure-cli
    command: ["/bin/sh","-c","echo 'Connecting to Azure...'; az login --identity --allow-no-subscriptions; echo 'Show Azure Subscription...'; az account list --all; echo 'Contecting to AKS'; az aks get-credentials --resource-group aks-azb-rg --name aks-azb;"]
  restartPolicy: OnFailure
```

Run kubectl command to created the POD

```bash
kubectl create -f demo.yaml -n azb-ns
```
The POD creation will take one or two minutes, use this command to check POD status.

```bash
kubectl get pods
NAME   READY   STATUS      RESTARTS   AGE
demo   0/1     Completed   0          82s
```
Once the status is completed validate the logs to see if the POD is connecting to Azure and the AKS Cluster with the user-assigned managed identity

Example: 
```bash
kubectl logs demo
Connecting to Azure...
[
  {
    "environmentName": "AzureCloud",
    "homeTenantId": "XXXXXXXXXXXXXXXXXXXX",
    "id": "XXXXXXXXXXXXXXXXXXXX",
    "isDefault": true,
    "managedByTenants": [
      {
        "tenantId": "XXXXXXXXXXXXXXXXXXXX"
      }
    ],
    "name": "Development",
    "state": "Enabled",
    "tenantId": "XXXXXXXXXXXXXXXXXXXX",
    "user": {
      "assignedIdentityInfo": "MSI",
      "name": "systemAssignedIdentity",
      "type": "servicePrincipal"
    }
  }
]
Show Azure Subscription...
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "XXXXXXXXXXXXXXXXXXXX",
    "id": "XXXXXXXXXXXXXXXXXXXX",
    "isDefault": true,
    "managedByTenants": [
      {
        "tenantId": "XXXXXXXXXXXXXXXXXXXX"
      }
    ],
    "name": "Development",
    "state": "Enabled",
    "tenantId": "XXXXXXXXXXXXXXXXXXXX",
    "user": {
      "assignedIdentityInfo": "MSI",
      "name": "systemAssignedIdentity",
      "type": "servicePrincipal"
    }
  }
]
Contecting to AKS
Merged "aks-azb" as current context in /root/.kube/config
```