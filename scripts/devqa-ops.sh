#!/usr/bin/env bash
# Dev+QA operator helper for EKS: start/stop nodegroups and open dashboard tunnels
# Usage examples:
#   ./scripts/devqa-ops.sh up|open|status|down
# Env overrides:
#   PROFILE=cluckin-bell-qa REGION=us-east-1 CLUSTER=cluckn-bell-nonprod ./scripts/devqa-ops.sh up
# Toggles:
#   SKIP_KUBE_LOGIN=1   # don't call aws eks update-kubeconfig
#   FORCE_KUBE_LOGIN=1  # force kubeconfig refresh
set -euo pipefail

PROFILE="${PROFILE:-cluckin-bell-qa}"
REGION="${REGION:-us-east-1}"
CLUSTER="${CLUSTER:-cluckn-bell-nonprod}"

command -v aws >/dev/null || { echo "aws not found"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
command -v jq >/dev/null || { echo "jq not found"; exit 1; }

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

kube_login() {
  if [[ "${SKIP_KUBE_LOGIN:-0}" == "1" ]]; then
    log "Skipping kubeconfig update (SKIP_KUBE_LOGIN=1)"
    return
  fi
  if kubectl config current-context 2>/dev/null | grep -q "${CLUSTER}"; then
    if [[ "${FORCE_KUBE_LOGIN:-0}" != "1" ]]; then
      log "Current kube context already targets ${CLUSTER}; not updating (set FORCE_KUBE_LOGIN=1 to force)"
      return
    fi
  fi
  log "Updating kubeconfig for ${CLUSTER}"
  aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER}" --profile "${PROFILE}" >/dev/null
}

list_nodegroups() {
  aws eks list-nodegroups --profile "${PROFILE}" --region "${REGION}" --cluster-name "${CLUSTER}" \
    | jq -r '.nodegroups[]'
}

scale_nodegroups() {
  local min="$1" des="$2" max="$3"
  local ng
  for ng in $(list_nodegroups); do
    log "Scaling nodegroup ${ng} to min=${min} desired=${des} max=${max}"
    aws eks update-nodegroup-config \
      --profile "${PROFILE}" --region "${REGION}" \
      --cluster-name "${CLUSTER}" --nodegroup-name "${ng}" \
      --scaling-config "minSize=${min},desiredSize=${des},maxSize=${max}" >/dev/null
  done
}

wait_nodes_ready() {
  kube_login
  log "Waiting for at least one Ready node..."
  local tries=60
  until kubectl get nodes -o json 2>/dev/null \
      | jq -e '[.items[] | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))] | length >= 1' >/dev/null; do
    tries=$((tries-1))
    if [ $tries -le 0 ]; then
      log "Timed out waiting for Ready nodes"
      kubectl get nodes || true
      exit 1
    fi
    sleep 10
  done
  kubectl get nodes -o wide
}

status() {
  kube_login
  log "Nodegroups:"
  for ng in $(list_nodegroups); do
    aws eks describe-nodegroup \
      --profile "${PROFILE}" --region "${REGION}" \
      --cluster-name "${CLUSTER}" --nodegroup-name "${ng}" \
      --query 'nodegroup.{name:nodegroupName,scaling:scalingConfig,status:status}' --output table
  done
  log "Nodes:"
  kubectl get nodes || true
  log "Namespaces:"
  kubectl get ns || true
}

open_tunnels() {
  kube_login
  cleanup() { log "Stopping tunnels..."; jobs -p | xargs -r kill; }
  trap cleanup EXIT

  # Monitoring
  if ! kubectl get ns monitoring >/dev/null 2>&1; then
    cat <<'EOF'
[INFO] Namespace 'monitoring' not found. If you have not installed monitoring yet, run:

  kubectl create namespace monitoring
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    -n monitoring \
    --set grafana.service.type=ClusterIP \
    --set prometheus.service.type=ClusterIP \
    --wait --timeout 10m

Then re-run: ./scripts/devqa-ops.sh open
EOF
  else
    if kubectl -n monitoring get svc kube-prometheus-stack-grafana >/dev/null 2>&1; then
      kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 >/dev/null 2>&1 &
      log "Grafana → http://localhost:3000"
      log "Grafana admin password:"
      kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d || true
      echo
    fi
    if kubectl -n monitoring get svc kube-prometheus-stack-prometheus >/dev/null 2>&1; then
      kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 &
      log "Prometheus → http://localhost:9090"
    fi
  fi

  # Argo CD (detect service name)
  if kubectl get ns argocd >/dev/null 2>&1; then
    local ARGO_SVC=""
    if kubectl -n argocd get svc argocd-server >/dev/null 2>&1; then
      ARGO_SVC="argocd-server"
    elif kubectl -n argocd get svc argo-cd-argocd-server >/dev/null 2>&1; then
      ARGO_SVC="argo-cd-argocd-server"
    fi
    if [[ -n "${ARGO_SVC}" ]]; then
      kubectl -n argocd wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s >/dev/null 2>&1 || true
      kubectl -n argocd port-forward svc/${ARGO_SVC} 8080:443 >/dev/null 2>&1 &
      log "Argo CD → https://localhost:8080 (user: admin)"
      log "Argo CD admin password:"
      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || true
      echo
    else
      log "Argo CD service not found (looked for argocd-server and argo-cd-argocd-server)."
    fi
  fi

  log "Press Ctrl+C to close tunnels."
  wait
}

up()   { kube_login; scale_nodegroups 1 1 1; wait_nodes_ready; }
down() { kube_login; scale_nodegroups 0 0 1; log "Scaled to 0/0/1 (safe to end session)."; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>
  up       Scale Dev+QA nodegroups to 1/1/1 and wait for nodes
  open     Open local tunnels (Grafana 3000, Prometheus 9090, Argo CD 8080)
  status   Show nodegroup and node status
  down     Scale Dev+QA nodegroups to 0/0/1

Env overrides:
  PROFILE (default: ${PROFILE})
  REGION  (default: ${REGION})
  CLUSTER (default: ${CLUSTER})
Toggles:
  SKIP_KUBE_LOGIN=1   # don't call aws eks update-kubeconfig
  FORCE_KUBE_LOGIN=1  # force kubeconfig refresh
EOF
}

cmd="${1:-}"
case "${cmd}" in
  up) up ;;
  open) open_tunnels ;;
  status) status ;;
  down) down ;;
  *) usage; exit 1 ;;
esac