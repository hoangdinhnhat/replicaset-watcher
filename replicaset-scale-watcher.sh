#!/bin/bash
# Custom Kubernetes controller to watch ReplicaSet scale events and report ready pod count
# Requirements: curl, jq, and access to K8s API (with proper token)

# Configurations
NAMESPACE="default"  # Change if needed
SERVICE_NAME="abshork-service"
ENDPOINT="/update-pods"
K8S_API="https://kubernetes.default.svc"
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

# Function to get ready pod count for a replicaset
get_ready_pod_count() {
  local rs_name="$1"
  curl -s --cacert "$CA_CERT" -H "Authorization: Bearer $TOKEN" \
    "$K8S_API/apis/apps/v1/namespaces/$NAMESPACE/replicasets/$rs_name" | \
    jq '.status.readyReplicas // 0'
}

# Function to send ready pod count to abshork-service
send_update() {
  local rs_name="$1"
  local ready_count="$2"
  curl -s -X POST "http://$SERVICE_NAME$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"replicaSet\": \"$rs_name\", \"readyPods\": $ready_count}"
}

# Watch for ReplicaSet events (scale in/out)
while true; do
  curl -s --cacert "$CA_CERT" -H "Authorization: Bearer $TOKEN" \
    "$K8S_API/apis/apps/v1/namespaces/$NAMESPACE/replicasets?watch=true" | \
  while read -r event; do
    event_type=$(echo "$event" | jq -r '.type')
    rs_name=$(echo "$event" | jq -r '.object.metadata.name')
    if [[ "$event_type" == "MODIFIED" ]]; then
      ready_count=$(get_ready_pod_count "$rs_name")
      send_update "$rs_name" "$ready_count"
    fi
  done
  sleep 1 # In case of disconnection, wait before retrying
done
