#!/usr/bin/env bash
# Dev+QA operator helper for EKS: start/stop nodegroups and open dashboard tunnels
# Commands: up | open | status | down | down-full | down-qa
# Env: PROFILE, REGION, CLUSTER
# Toggles: SKIP_KUBE_LOGIN=1 (skip kubeconfig update), FORCE_KUBE_LOGIN=1 (force update)
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

scale_nodegroup() {
  local ng="$1" min="$2" des="$3" max="$4"
  log "Scaling nodegroup ${ng} to min=${min} desired=${des} max=${max}"
  aws eks update-nodegroup-config \
    --profile "${PROFILE}" --region "${REGION}" \
    --cluster-name "${CLUSTER}" --nodegroup-name "${ng}" \
    --scaling-config "minSize=${min},desiredSize=${des},maxSize=${max}" >/dev/null
}

scale_all_nodegroups() {
  local min="$1" des="$2" max="$3"
  local ngs; ngs=$(list_nodegroups || true)
  if [[ -z "${ngs}" ]]; then
    log "No nodegroups found in ${CLUSTER}"
    return
  fi
  while read -r ng; do
    [[ -z "$ng" ]] && continue
    scale_nodegroup "$ng" "$min" "$des" "$max"
  done <<< "${ngs}"
}

scale_named_nodegroups() {
  local min="$1" des="$2" max="$3"
  # Explicitly ensure dev and qa nodegroups are scaled, in case list call ever misses one
  for ng in dev-t3 qa-t3; do
    if aws eks describe-nodegroup --profile "${PROFILE}" --region "${REGION}" \
        --cluster-name "${CLUSTER}" --nodegroup-name "${ng}" >/dev/null 2>&1; then
      scale_nodegroup "$ng" "$min" "$des" "$max"
    fi
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

# During shutdown, PDBs can block the last node from draining
relax_pdbs_for_shutdown() {
  log "Relaxing/removing PDBs that commonly block drains (nonprod only)"
  # coredns (kube-system) — remove PDB
  kubectl -n kube-system delete pdb coredns >/dev/null 2>&1 || true

  # Monitoring stack PDBs (names vary by chart version) — remove any PDBs in monitoring
  for pdb in $(kubectl -n monitoring get pdb -o name 2>/dev/null || true); do
    kubectl -n monitoring delete "$pdb" >/dev/null 2>&1 || true
  done

  # Argo CD server/controller PDBs if present
  for pdb in $(kubectl -n argocd get pdb -o name 2>/dev/null || true); do
    kubectl -n argocd delete "$pdb" >/dev/null 2>&1 || true
  done
}

force_drain_and_terminate_remaining_nodes() {
  log "Force-draining and terminating any remaining nodes"
  local nodes; nodes=$(kubectl get nodes -o name 2>/dev/null || true)
  [[ -z "${nodes}" ]] && { log "No nodes found"; return; }

  while read -r n; do
    [[ -z "$n" ]] && continue
    log "Draining $n"
    kubectl drain "$n" --ignore-daemonsets --delete-emptydir-data --force --grace-period=30 --timeout=5m || true

    local iid; iid=$(kubectl get "$n" -o jsonpath='{.spec.providerID}' | awk -F/ '{print $NF}')
    if [[ -n "$iid" ]]; then
      local asg
      asg=$(aws ec2 describe-instances --region "${REGION}" --profile "${PROFILE}" --instance-ids "${iid}" \
            --query 'Reservations[0].Instances[0].Tags[?Key==`aws:autoscaling:groupName`].Value' --output text 2>/dev/null || true)
      [[ -n "${asg}" ]] && aws autoscaling set-instance-protection --region "${REGION}" --profile "${PROFILE}" \
        --auto-scaling-group-name "${asg}" --instance-ids "${iid}" --no-protected-from-scale-in >/dev/null 2>&1 || true

      log "Terminating instance ${iid} (ASG: ${asg:-unknown})"
      aws autoscaling terminate-instance-in-auto-scaling-group --region "${REGION}" --profile "${PROFILE}" \
        --instance-id "${iid}" --should-decrement-desired-capacity >/dev/null || true
    fi
  done <<< "${nodes}"
}

stop_bastions() {
  log "Stopping bastion instances (if any)"
  local bastions
  bastions=$(aws ec2 describe-instances --region "${REGION}" --profile "${PROFILE}" \
    --filters "Name=tag:Name,Values=*bastion*" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" --output text 2>/dev/null || true)
  if [[ -n "${bastions:-}" ]]; then
    for b in ${bastions}; do
      log "Stopping bastion ${b}"
      aws ec2 stop-instances --region "${REGION}" --profile "${PROFILE}" --instance-ids "${b}" >/dev/null || true
    done
  else
    log "No running bastions found."
  fi
}

status() {
  kube_login
  log "Nodegroups:"
  for ng in $(list_nodegroups); do
    aws eks describe-nodegroup --profile "${PROFILE}" --region "${REGION}" \
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
  cleanup() { log "Stopping tunnels..."; jobs -p | xargs -r kill >/dev/null 2>&1 || true; }
  trap cleanup EXIT

  # Monitoring
  if kubectl get ns monitoring >/dev/null 2>&1 && kubectl -n monitoring get svc kube-prometheus-stack-grafana >/dev/null 2>&1; then
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 >/dev/null 2>&1 &
    log "Grafana → http://localhost:3000"
    log "Grafana admin password:"; kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d || true; echo
  else
    log "Grafana service not found (namespace 'monitoring')."
  fi
  if kubectl get ns monitoring >/dev/null 2>&1 && kubectl -n monitoring get svc kube-prometheus-stack-prometheus >/dev/null 2>&1; then
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 &
    log "Prometheus → http://localhost:9090"
  fi

  # Argo CD (optional)
  if kubectl get ns argocd >/dev/null 2>&1; then
    local ARGO_SVC=""
    if kubectl -n argocd get svc argocd-server >/dev/null 2>&1; then ARGO_SVC="argocd-server"; fi
    if kubectl -n argocd get svc argo-cd-argocd-server >/dev/null 2>&1; then ARGO_SVC="argo-cd-argocd-server"; fi
    if [[ -n "${ARGO_SVC}" ]]; then
      kubectl -n argocd wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s >/dev/null 2>&1 || true
      kubectl -n argocd port-forward svc/${ARGO_SVC} 8080:443 >/dev/null 2>&1 &
      log "Argo CD → https://localhost:8080 (user: admin)"
      log "Argo CD admin password:"; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || true; echo
    else
      log "Argo CD service not found."
    fi
  fi

  log "Press Ctrl+C to close tunnels."
  wait || true
}

up() { kube_login; scale_all_nodegroups 1 1 1; scale_named_nodegroups 1 1 1; wait_nodes_ready; }

down() {
  kube_login
  # First try standard scale-to-zero for all nodegroups (dev + qa)
  scale_all_nodegroups 0 0 1
  scale_named_nodegroups 0 0 1
  log "Requested 0/0/1 for all nodegroups. Nodes may take a few minutes to terminate."
}

down_full() {
  kube_login
  scale_all_nodegroups 0 0 1
  scale_named_nodegroups 0 0 1
  # Remove known PDB blocks, drain, and terminate any lingering nodes
  relax_pdbs_for_shutdown
  force_drain_and_terminate_remaining_nodes
  # Optionally stop bastions
  [[ "${STOP_BASTION:-1}" == "1" ]] && stop_bastions
  log "Full shutdown complete."
}

down_qa_only() {
  kube_login
  # Explicitly target qa nodegroup if present
  if aws eks describe-nodegroup --profile "${PROFILE}" --region "${REGION}" \
      --cluster-name "${CLUSTER}" --nodegroup-name qa-t3 >/dev/null 2>&1; then
    scale_nodegroup qa-t3 0 0 1
  else
    log "qa-t3 nodegroup not found"
  fi
  # Drain nodes labeled for qa (best-effort)
  for n in $(kubectl get nodes -o name --show-labels | grep -E 'eks\.amazonaws\.com/nodegroup-name=qa-t3' | awk '{print $1}' || true); do
    log "Draining $n"; kubectl drain "$n" --ignore-daemonsets --delete-emptydir-data --force --grace-period=30 --timeout=5m || true
  done
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>
  up           Scale Dev+QA nodegroups to 1/1/1 and wait for nodes
  open         Open local tunnels (Grafana 3000, Prometheus 9090, Argo CD 8080)
  status       Show nodegroup and node status
  down         Scale Dev+QA nodegroups to 0/0/1 (graceful)
  down-full    Scale to 0 and force drain/terminate any remaining nodes; stop bastion (STOP_BASTION=0 to skip)
  down-qa      Scale only the QA nodegroup (qa-t3) to 0/0/1 and drain QA nodes

Env overrides:
  PROFILE (default: ${PROFILE})
  REGION  (default: ${REGION})
  CLUSTER (default: ${CLUSTER})
Toggles:
  SKIP_KUBE_LOGIN=1   # don't call aws eks update-kubeconfig
  FORCE_KUBE_LOGIN=1  # force kubeconfig refresh
  STOP_BASTION=0|1    # used by down-full (default 1 = stop)
EOF
}

cmd="${1:-}"; case "${cmd}" in
  up) up ;;
  open) open_tunnels ;;
  status) status ;;
  down) down ;;
  down-full) down_full ;;
  down-qa) down_qa_only ;;
  *) usage; exit 1 ;;
esac