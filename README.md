# Enterprise Bot — DevOps / Platform Engineer take-home (v2)

## Status / scope

- **Part 1:** Python 3.12 standard-library HTTP service, multi-stage Dockerfile and non-root runtime.
- **Part 2:** Helm Deployment, ConfigMap, Service, Ingress, two probes, resources, and overrideable values.
- **Part 3:** idempotent `setup.sh` for kind cluster `demo`, pinned ingress-nginx controller, build/load, and Helm release `demo` in namespace `demo`.
- **Part 4:** Six lab defects were identified using manifest inspection and genuine Kubernetes events/logs, and fixes are in the chart. A hosted kind cluster confirms 7/11 verifier checks; the other four still fail (reporter API call plus an apparent short-lived probe attachment/output race). This is **not yet a fully passing submission**. See `lab/FINDINGS.md` and the real `lab/part4-session.log`.
- **Part 5:** Gateway API migration rationale in `ANSWERS.md`.

## Prerequisites

Docker (running daemon), kind, kubectl, Helm, and curl; allow local host ports 80 and 443. Linux/macOS/WSL2 with Linux containers recommended. Network access is required to pull public images and the pinned ingress-nginx manifest. No cloud account or secrets required.

## Run everything

```bash
chmod +x setup.sh
./setup.sh
./setup.sh    # idempotency check; should exit successfully again
```

Kind context: `kind-demo`. The script builds `demo-service:1.0.0`, loads it into kind, creates/updates ingress-nginx, and applies the chart. Existing clusters are reused; if `demo` was created without ports 80/443 or the `ingress-ready=true` label, use a fresh cluster instead.

## Verify service

```bash
kubectl config use-context kind-demo
kubectl -n demo get deployment,pods,svc,configmap,ingress
kubectl -n demo rollout status deployment/demo
kubectl -n demo get deploy demo -o jsonpath='{.status.readyReplicas}'
curl -fsS --resolve demo.local:80:127.0.0.1 http://demo.local/
curl -fsS --resolve demo.local:80:127.0.0.1 http://demo.local/healthz
```

If ports 80/443 are unavailable locally, use a temporary port-forward to verify app separately:

```bash
kubectl -n demo port-forward service/demo 8080:80
# In a second terminal:
curl -fsS http://localhost:8080/
```

Expected root response is JSON with `app`, `version`, and the Kubernetes pod's hostname. `/healthz` returns HTTP 200. The endpoints and idempotent setup were tested successfully on a GitHub-hosted Linux runner with a temporary kind cluster; the GitHub Actions logs contain the observed output.

## Test Helm overrides and live ConfigMap updates

```bash
helm lint ./chart
helm template demo ./chart -n demo --set replicaCount=3 \
  --set config.appName=overridden --set config.version=2.5.0 \
  --set ingress.host=demo.local
helm upgrade demo ./chart -n demo --reuse-values \
  --set replicaCount=3 --set config.appName=overridden --set config.version=2.5.0
kubectl -n demo rollout status deployment/demo
curl -fsS --resolve demo.local:80:127.0.0.1 http://demo.local/
# Restore defaults after the override test:
helm upgrade demo ./chart -n demo --reset-values

# Optional: verify behavior on a direct ConfigMap patch (no restart required):
kubectl -n demo patch configmap demo-config --type merge \
  -p '{"data":{"APP_NAME":"patched","VERSION":"3.2.1"}}'
# The kubelet updates projected ConfigMap files eventually, not instantly.
# Poll for up to about 2 minutes before concluding it did not propagate.
curl -fsS --resolve demo.local:80:127.0.0.1 http://demo.local/
```

Environment variables `APP_NAME` and `VERSION` are set via ConfigMap (`envFrom`). Kubernetes environment variables are immutable within running processes. To support direct ConfigMap patches, the same ConfigMap is also mounted as a directory (not `subPath`), and the app re-reads the projected values on requests; it falls back to the environment when those files are absent, such as in a plain Docker run. Helm changes also trigger a rollout via a ConfigMap template checksum annotation.

## Part 4 — run the actual debug lab and capture real evidence

A genuine terminal recording from a GitHub-hosted kind cluster is included as `lab/part4-session.log`. Current verifier results are 7/11, **not** green. For a repeat run, record your own terminal session **before investigating**:

```bash
cd lab
script -q part4-session.log
./scenario.sh up
./scenario.sh verify
kubectl -n debug-lab get pods -o wide
kubectl -n debug-lab get events --sort-by=.lastTimestamp
kubectl -n debug-lab describe deploy worker
kubectl -n debug-lab logs deploy/worker --all-containers --tail=100
kubectl -n debug-lab logs deploy/worker --previous --all-containers --tail=100
kubectl -n debug-lab describe deploy backend
kubectl -n debug-lab logs deploy/backend --all-containers --tail=100
kubectl -n debug-lab describe deploy reporter
kubectl -n debug-lab logs deploy/reporter --all-containers --tail=100
kubectl -n debug-lab describe deploy gateway
kubectl -n debug-lab logs deploy/gateway --all-containers --tail=100
kubectl -n debug-lab describe deploy metrics
kubectl -n debug-lab get job,pods
kubectl auth can-i list pods -n debug-lab --as=system:serviceaccount:debug-lab:reporter
# After modifying the chart based on actual evidence:
./scenario.sh up
./scenario.sh verify
exit
```

Inspect the **real** output in `lab/part4-session.log` and the six entries of `lab/FINDINGS.md`. The included `lab/scenario.sh` and `lab/cluster-state/` are verbatim copies of the handout. Do not alter the lab image repository or tag.

> Tip: if a container has no shell, use `kubectl describe`, container logs and `kubectl debug` with an ephemeral debug image; avoid `kubectl exec ... sh` assumptions. Inspect the Service endpoints and test HTTP/DNS from a temporary BusyBox pod.

## Resource decisions

- `50m` CPU and `64Mi` RAM request per main-service replica: suitable for this tiny stdlib HTTP server in a local kind cluster without reserving excessive resources.
- `200m` CPU and `128Mi` RAM limit: allows short bursts while preventing a demo service from exhausting the cluster. Right-size under a real load test; Python is also affected by CPU throttling.
- Part 4 metrics CPU was reduced to `50m` request and `200m` limit because the supplied namespace `LimitRange` restricts individual containers to at most 1 CPU. The lab itself supplies similar `50m/64Mi` requests elsewhere.

## Deliberately skipped, with risks

- No TLS/certificate management: HTTP and `demo.local` are **local-only**, unencrypted.
- No production persistent data or external store: requests are stateless, and pod restarts lose any hypothetical in-memory state.
- No authentication or NetworkPolicy: not appropriate for exposed production networks.
- No HPA/PDB/topology spreading, performance tests, or advanced observability: scaling resilience and saturation behavior are unproven.
- **Part 4 remains incomplete:** actual hosted-kind terminal output is included, but final `./scenario.sh verify` has 7/11 PASS, not 11/11. The reporter could not decode the pod list from Kubernetes API and the short-lived in-cluster verifier probe missed early output. These are not silently labeled as passing.

## Production-ready improvements

Use a currently supported Gateway API controller rather than end-of-life ingress-nginx; add cert-manager/TLS, authentication, RBAC and NetworkPolicies; pin container images by digest, run continuous vulnerability scans/SBOM, set pod disruption budgets, tune HPA and topology spreading, configure structured logs/metrics/tracing, and run smoke/load/chaos tests. Support promotion with immutable image digests and GitOps plus per-environment values. Restrict service and route access as appropriate.

## How I used AI

I used **ChatGPT (OpenAI)** to analyze the assignment, generate and revise Python/Docker/Helm/setup files, debug chart defects, draft the migration answer and documentation, and orchestrate **real GitHub Actions Linux runners** with Docker, kind, kubectl and Helm because I did not have a laptop. I reviewed the genuine runner logs to correct AI guesses about ports, read-only filesystem, UID handling and image vulnerabilities. GitHub-hosted kind verification is real, not synthetic output, but the final 11-check lab verifier is not yet green. I must be able to explain the files, errors, trade-offs, and commands independently in the live assessment.

## Local unit test

```bash
cd service
python3 -m unittest -v test_app.py
```

## Optional CI

The GitHub Actions workflow in `.github/workflows/ci.yml` runs the Python unit tests, Helm lint/template, builds the container, and scans its vulnerabilities with Trivy (HIGH/CRITICAL errors cause failure). CI does not substitute for the Part 4 recording.