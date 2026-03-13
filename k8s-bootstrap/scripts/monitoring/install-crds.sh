#!/bin/bash
# Prometheus Operator CRD 설치
# ArgoCD로 prometheus-stack 배포 전에 실행 필요

set -e

PROMETHEUS_OPERATOR_VERSION="v0.75.1"
BASE_URL="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PROMETHEUS_OPERATOR_VERSION}/example/prometheus-operator-crd"

echo "=== Installing Prometheus Operator CRDs (${PROMETHEUS_OPERATOR_VERSION}) ==="

CRDS=(
  "monitoring.coreos.com_alertmanagerconfigs.yaml"
  "monitoring.coreos.com_alertmanagers.yaml"
  "monitoring.coreos.com_podmonitors.yaml"
  "monitoring.coreos.com_probes.yaml"
  "monitoring.coreos.com_prometheusagents.yaml"
  "monitoring.coreos.com_prometheuses.yaml"
  "monitoring.coreos.com_prometheusrules.yaml"
  "monitoring.coreos.com_scrapeconfigs.yaml"
  "monitoring.coreos.com_servicemonitors.yaml"
  "monitoring.coreos.com_thanosrulers.yaml"
)

for crd in "${CRDS[@]}"; do
  echo "  Installing ${crd}..."
  kubectl apply --server-side -f "${BASE_URL}/${crd}"
done

echo ""
echo "=== Prometheus Operator CRDs installed ==="
kubectl get crd | grep monitoring.coreos.com
