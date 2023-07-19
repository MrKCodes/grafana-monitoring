#!/bin/bash
set -e

# Check if CLUSTER_NAME is set
if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "CLUSTER_NAME environment variable is required"
  exit 1
fi

# Check if GITOPS_PAT_TOKEN is set
if [[ -z "${GITOPS_PAT_TOKEN}" ]]; then
  echo "GITOPS_PAT_TOKEN environment variable is required"
  exit 1
fi

# Check if GRAFANA_AAD_CLIENT_SECRET is set
if [[ -z "${GRAFANA_AAD_CLIENT_SECRET}" ]]; then
  echo "GRAFANA_AAD_CLIENT_SECRET environment variable is required"
  exit 1
fi

# Check if GRAFANA_AAD_CLIENT_ID is set
if [[ -z "${GRAFANA_AAD_CLIENT_ID}" ]]; then
  echo "GRAFANA_AAD_CLIENT_ID environment variable is required"
  exit 1
fi

# Check if LOKI_BLOB_ACCOUNT_KEY is set
if [[ -z "${LOKI_BLOB_ACCOUNT_KEY}" ]]; then
  echo "LOKI_BLOB_ACCOUNT_KEY environment variable is required"
  exit 1
fi

cp -r templates/monitoring-system configs/$CLUSTER_NAME

# Create namespace
kubectl create namespace grafana-ui || true
kubectl create namespace loki || true
kubectl create namespace vm-system || true
kubectl create namespace grafana-agent || true
kubectl create namespace vm-scout || true
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true

# Grafana default fields
GRAFANA_AAD_AUTH_URL="${GRAFANA_AAD_AUTH_URL:-https://login.microsoftonline.com/217024cc-23bf-42d2-a7cf-d270166db3e2/oauth2/v2.0/authorize}"
GRAFANA_AAD_TOKEN_URL="${GRAFANA_AAD_TOKEN_URL:-https://login.microsoftonline.com/217024cc-23bf-42d2-a7cf-d270166db3e2/oauth2/v2.0/token}"

# Generate a self-signed certificate using openssl
openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt -days 365 -nodes -subj "/CN=grafana-ui"

# Loki read credentials
LOKI_READ_USERNAME="loki_read_user"
LOKI_READ_PASSWORD=$(openssl rand -base64 12)

# Loki push credentials
LOKI_PUSH_USERNAME="loki_push_user"
LOKI_PUSH_PASSWORD=$(openssl rand -base64 12)

# Loki self credentials
LOKI_SELF_USERNAME="loki_self_user"
LOKI_SELF_PASSWORD=$(openssl rand -base64 12)

# Grafana Admin credentials
GRAFANA_ADMIN_USERNAME="grafana_admin"
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 12)

# VictoriaMetrics system read credentials
VM_SYSTEM_READ_USERNAME="vm_system_read_user"
VM_SYSTEM_READ_PASSWORD=$(openssl rand -base64 12)

# VictoriaMetrics system push credentials
VM_SYSTEM_PUSH_USERNAME="vm_system_push_user"
VM_SYSTEM_PUSH_PASSWORD=$(openssl rand -base64 12)

# VictoriaMetrics system self credentials
VM_SYSTEM_SELF_USERNAME="vm_system_self_user"
VM_SYSTEM_SELF_PASSWORD=$(openssl rand -base64 12)

# VictoriaMetrics scout read credentials
VM_scout_READ_USERNAME="vm_scout_read_user"
VM_scout_READ_PASSWORD=$(openssl rand -base64 12)

# VictoriaMetrics scout push credentials
VM_scout_PUSH_USERNAME="vm_scout_push_user"
VM_scout_PUSH_PASSWORD=$(openssl rand -base64 12)

# Generate htpasswd entries
LOKI_HTPASSWD_READ=$(htpasswd -nbB ${LOKI_READ_USERNAME} ${LOKI_READ_PASSWORD})
LOKI_HTPASSWD_PUSH=$(htpasswd -nbB ${LOKI_PUSH_USERNAME} ${LOKI_PUSH_PASSWORD})
LOKI_HTPASSWD_SELF=$(htpasswd -nbB ${LOKI_SELF_USERNAME} ${LOKI_SELF_PASSWORD})

# Create Kubernetes secrets
kubectl create secret generic grafana-config-secret \
  --from-literal=GRAFANA_AAD_AUTH_URL=${GRAFANA_AAD_AUTH_URL} \
  --from-literal=GRAFANA_AAD_TOKEN_URL=${GRAFANA_AAD_TOKEN_URL} \
  --from-literal=GRAFANA_AAD_CLIENT_SECRET=${GRAFANA_AAD_CLIENT_SECRET} \
  --from-literal=GRAFANA_AAD_CLIENT_ID=${GRAFANA_AAD_CLIENT_ID} \
  -n grafana-ui -o yaml --dry-run=client > configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic grafana-tls-secret --from-file=tls.crt=tls.crt --from-file=tls.key=tls.key -n grafana-ui -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic credentials-grafana --from-literal=admin_username=${GRAFANA_ADMIN_USERNAME} --from-literal=admin_password=${GRAFANA_ADMIN_PASSWORD} -n grafana-ui -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic datasource-loki-read-credentials --from-literal=LOKI_USERNAME=${LOKI_READ_USERNAME} --from-literal=LOKI_PASSWORD=${LOKI_READ_PASSWORD} -n loki -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic loki-push-credentials --from-literal=LOKI_USERNAME=${LOKI_PUSH_USERNAME} --from-literal=LOKI_PASSWORD=${LOKI_PUSH_PASSWORD} -n loki -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic loki-self-credentials --from-literal=LOKI_USERNAME=${LOKI_SELF_USERNAME} --from-literal=LOKI_PASSWORD=${LOKI_SELF_PASSWORD} -n grafana-agent -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic loki-htpasswd --from-file=.htpasswd=<(echo -e "${LOKI_HTPASSWD_READ}\n${LOKI_HTPASSWD_PUSH}\n${LOKI_HTPASSWD_SELF}") -n loki -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic loki-config-secret --from-literal=accountKey=${LOKI_BLOB_ACCOUNT_KEY} -n loki -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic datasource-vm-system-read-credentials --from-literal=VM_USERNAME=${VM_SYSTEM_READ_USERNAME} --from-literal=VM_PASSWORD=${VM_SYSTEM_READ_PASSWORD} -n vm-system -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic vm-system-push-credentials --from-literal=VM_USERNAME=${VM_SYSTEM_PUSH_USERNAME} --from-literal=VM_PASSWORD=${VM_SYSTEM_PUSH_PASSWORD} -n vm-system -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic vm-system-selfmonitoring-credentials --from-literal=VM_USERNAME=${VM_SYSTEM_SELF_USERNAME} --from-literal=VM_PASSWORD=${VM_SYSTEM_SELF_PASSWORD} -n grafana-agent -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic datasource-vm-scout-read-credentials --from-literal=VM_USERNAME=${VM_scout_READ_USERNAME} --from-literal=VM_PASSWORD=${VM_scout_READ_PASSWORD} -n vm-scout -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/credentials-secrets.yaml
kubectl create secret generic vm-scout-push-credentials --from-literal=VM_USERNAME=${VM_scout_PUSH_USERNAME} --from-literal=VM_PASSWORD=${VM_scout_PUSH_PASSWORD} -n vm-scout -o yaml --dry-run=client >> configs/$CLUSTER_NAME/credentials-secrets.yaml

kubectl create secret generic vm-system-push-credentials --from-literal=VM_USERNAME=${VM_SYSTEM_PUSH_USERNAME} --from-literal=VM_PASSWORD=${VM_SYSTEM_PUSH_PASSWORD} -n grafana-agent -o yaml --dry-run=client > configs/$CLUSTER_NAME/grafana-agent-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/grafana-agent-secrets.yaml
kubectl create secret generic vm-scout-push-credentials --from-literal=VM_USERNAME=${VM_scout_PUSH_USERNAME} --from-literal=VM_PASSWORD=${VM_scout_PUSH_PASSWORD} -n grafana-agent -o yaml --dry-run=client >> configs/$CLUSTER_NAME/grafana-agent-secrets.yaml
echo '---' >> configs/$CLUSTER_NAME/grafana-agent-secrets.yaml
kubectl create secret generic loki-push-credentials --from-literal=LOKI_USERNAME=${LOKI_PUSH_USERNAME} --from-literal=LOKI_PASSWORD=${LOKI_PUSH_PASSWORD} -n grafana-agent -o yaml --dry-run=client >> configs/$CLUSTER_NAME/grafana-agent-secrets.yaml


# Add PAT Token
cat << EOF >> configs/$CLUSTER_NAME/credentials-secrets.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: azure-devops-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: https://dev.azure.com/SorocoProducts/Scout/_git/MonitoringPlatformGitOps
  password: $GITOPS_PAT_TOKEN
  username: argocd
EOF


# Remove certificate files
rm -f tls.crt tls.key

# Echo credentials
echo "Credentials for $CLUSTER_NAME:"
echo "Grafana Admin: ${GRAFANA_ADMIN_USERNAME} / ${GRAFANA_ADMIN_PASSWORD}"
echo "Loki Read: ${LOKI_READ_USERNAME} / ${LOKI_READ_PASSWORD}"
echo "Loki Push: ${LOKI_PUSH_USERNAME} / ${LOKI_PUSH_PASSWORD}"
echo "VM System Read: ${VM_SYSTEM_READ_USERNAME} / ${VM_SYSTEM_READ_PASSWORD}"
echo "VM System Push: ${VM_SYSTEM_PUSH_USERNAME} / ${VM_SYSTEM_PUSH_PASSWORD}"
echo "VM scout Read: ${VM_scout_READ_USERNAME} / ${VM_scout_READ_PASSWORD}"
echo "VM scout Push: ${VM_scout_PUSH_USERNAME} / ${VM_scout_PUSH_PASSWORD}"
echo "argocd password: "
argocd admin initial-password -n argocd

# Save the content in Keeper
echo "Please save the content of the configs/$CLUSTER_NAME/credentials-secrets.yaml and configs/$CLUSTER_NAME/grafana-agent-secrets.yaml file in Keeper before applying to the server"
echo "Deploy kubectl apply -f configs/$CLUSTER_NAME/grafana-agent-secrets.yaml on cluster targeted to be monitored by this platform"