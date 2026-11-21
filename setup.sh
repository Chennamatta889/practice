#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER=demo
NAMESPACE=demo
RELEASE=demo
IMAGE=demo-service:1.0.0
# Intentionally pinned: ingress-nginx is only here to meet the local assignment;
# it is end-of-life and should not be selected for production.
INGRESS_MANIFEST=https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml

for cmd in docker kind kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' is required. Install it and retry." >&2
    exit 1
  fi
done

docker info >/dev/null 2>&1 || { echo 'ERROR: Docker daemon is not running' >&2; exit 1; }

if ! kind get clusters | grep -Fxq "$CLUSTER"; then
  echo '==> Creating kind cluster demo with local Ingress ports 80/443'
  kind create cluster --name "$CLUSTER" --config - <<'KIND_CONFIG'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
KIND_CONFIG
else
  echo '==> Reusing kind cluster demo'
fi

# Ensure we always deploy into kind-demo even if a different context was active.
kubectl config use-context "kind-${CLUSTER}" >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo '==> Installing/updating ingress-nginx'
kubectl apply -f "$INGRESS_MANIFEST"
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=240s

echo "==> Building and loading $IMAGE"
docker build -t "$IMAGE" "$ROOT/service"
kind load docker-image "$IMAGE" --name "$CLUSTER"

echo '==> Installing/upgrading Helm release demo in namespace demo'
helm upgrade --install "$RELEASE" "$ROOT/chart" \
  --namespace "$NAMESPACE" --create-namespace \
  --set-string image.repository=demo-service --set-string image.tag=1.0.0 \
  --wait --timeout 240s
kubectl -n "$NAMESPACE" rollout status deployment/demo --timeout=180s

echo ''
echo 'Ready. Verify:'
echo '  kubectl -n demo get pods,svc,ingress'
echo "  curl -sS --resolve demo.local:80:127.0.0.1 http://demo.local/"
echo "  curl -sS --resolve demo.local:80:127.0.0.1 http://demo.local/healthz"
