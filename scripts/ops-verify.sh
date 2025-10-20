#!/usr/bin/env bash
set -euo pipefail
NS_MON="monitoring"
NS_ARGO="argocd"

pass() { printf "✔ %s\n" "$*"; }
fail() { printf "✘ %s\n" "$*"; exit 1; }

# Nodes
kubectl get nodes >/dev/null || fail "kubectl cannot reach the cluster"
if kubectl get nodes -o json | jq -e '[.items[] | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))] | length >= 1' >/dev/null; then
  pass "At least one Ready node"
else
  fail "No Ready nodes; run: make ops-up"
fi

# Monitoring
kubectl get ns "${NS_MON}" >/dev/null 2>&1 && pass "Namespace '${NS_MON}' exists" || fail "Namespace '${NS_MON}' missing"
kubectl -n "${NS_MON}" get svc kube-prometheus-stack-grafana kube-prometheus-stack-prometheus >/dev/null 2>&1 && pass "Grafana/Prometheus Services present" || fail "Grafana/Prometheus Services missing"
kubectl -n "${NS_MON}" wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana --timeout=300s >/dev/null && pass "Grafana pod Ready" || fail "Grafana pod not Ready"
kubectl -n "${NS_MON}" wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus --timeout=300s >/dev/null && pass "Prometheus pod Ready" || fail "Prometheus pod not Ready"

# Argo CD
if kubectl get ns "${NS_ARGO}" >/dev/null 2>&1; then
  pass "Namespace '${NS_ARGO}' exists"
  if kubectl -n "${NS_ARGO}" get svc argocd-server >/dev/null 2>&1 || kubectl -n "${NS_ARGO}" get svc argo-cd-argocd-server >/dev/null 2>&1; then
    pass "Argo CD server Service present"
  else
    fail "Argo CD server Service missing (expected argocd-server or argo-cd-argocd-server)"
  fi
  kubectl -n "${NS_ARGO}" wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s >/dev/null && pass "Argo CD server pod Ready" || fail "Argo CD server pod not Ready"
else
  fail "Namespace '${NS_ARGO}' missing"
fi

echo "All checks passed."