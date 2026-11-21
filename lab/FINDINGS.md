# Part 4 — Findings (in progress, **not** a completed incident report)

**Evidence rule:** Paste real terminal output from your own cluster below and record the session in `part4-session.log` or `part4-session.cast`. Nothing in this file is presented as observed kubectl output. Four defects are provable by reviewing the supplied manifests; two need runtime investigation. The session recording is deliberately *not* fabricated.

## Defect 1 — Migration Job restart policy

**Symptom (actual output):** _Pending local cluster run. Capture `./scenario.sh up`, Helm's Kubernetes validation error and `kubectl -n debug-lab get job migrate`._

**Cause:** `lab/broken-chart/templates/migrate-job.yaml` specified `restartPolicy: Always`. `batch/v1` Job pod templates only allow `Never` or `OnFailure`.

**Fix:** Set `restartPolicy: Never` while retaining the Job, image and backoff limit. With `Never`, retries are handled by the Job controller.

**How I found it:** Manifest inspection -> check the Job's pod-spec restart policy -> compare with Kubernetes Job validation -> plan to reproduce by running `./scenario.sh up` and recording the exact error.

---

## Defect 2 — Metrics exceeds LimitRange

**Symptom (actual output):** _Pending local run. Capture pod events using `kubectl -n debug-lab describe deploy metrics` and `kubectl -n debug-lab get events --sort-by=.lastTimestamp` after Job validation is fixed._

**Cause:** The environment's immutable `LimitRange` sets per-container max CPU to `1`, but `metrics` requests `2` CPU and limits to `4` CPU. The API server rejects that Pod.

**Fix:** Change `metrics.resources.requests.cpu` to `50m` and `limits.cpu` to `200m`. Both fit under the guardrail; leave `cluster-state/` unchanged.

**How I found it:** Compared `values.yaml` with `cluster-state/limits.yaml` -> identified impossible values -> plan to confirm pod admission errors/events after applying the corrected Job.

---

## Defect 3 — Gateway backend service address

**Symptom (actual output):** _Pending local run. Capture gateway `/status` returned body and `kubectl -n debug-lab logs deploy/gateway`._

**Cause:** The gateway's `BACKEND_URL` pointed to `http://backend.default.svc:8080`, but the backend Service is in namespace `debug-lab`, so lookup/service routing targets the wrong namespace.

**Fix:** Set `BACKEND_URL=http://backend.debug-lab.svc.cluster.local:8080` in the chart values.

**How I found it:** Compared namespace supplied by `scenario.sh` with `gateway.env.BACKEND_URL` -> inspect the actual Service name/port -> plan to confirm DNS and HTTP from inside the namespace.

---

## Defect 4 — Reporter RBAC subject mismatch

**Symptom (actual output):** _Pending local run. Capture `kubectl auth can-i list pods -n debug-lab --as=system:serviceaccount:debug-lab:reporter` and `kubectl -n debug-lab logs deploy/reporter`._

**Cause:** Reporter Deployment uses ServiceAccount `reporter`; the RoleBinding grants the Role to ServiceAccount `default`, not `reporter`.

**Fix:** Change RoleBinding `subjects[0].name` to `reporter`. Keep the Role namespace-scoped and limited to `get,list` on pods.

**How I found it:** Traced Deployment `.spec.template.spec.serviceAccountName` to RoleBinding `.subjects` -> found mismatch -> plan to reproduce with `kubectl auth can-i`.

---

## Defect 5 — To establish from actual runtime

**Symptom (actual output):** _Not investigated on a live cluster. Paste real events/logs and `./scenario.sh verify` output._

**Cause:** _Undetermined. Do not label a hypothesis as fact._

**Fix:** _Change only the chart after identifying the failing process/probe/event. Do not weaken security or delete workloads without evidence._

**How I found it:** _Record a genuine diagnostic sequence, likely `kubectl -n debug-lab get pods -o wide`, `kubectl describe pod`, and current/previous logs of unready/crash-looping Pods._

---

## Defect 6 — To establish from actual runtime

**Symptom (actual output):** _Not investigated on a live cluster. Paste real events/logs and `./scenario.sh verify` output._

**Cause:** _Undetermined._

**Fix:** _Pending confirmed diagnosis._

**How I found it:** _Once the earlier defects are repaired, inspect remaining failing `verify` checks; test Service endpoints, DNS, app-specific logs and health endpoints._

---

**Next step:** `cd lab && script -q part4-session.log` **before debugging**. Run `./scenario.sh up`, then `./scenario.sh verify`, inspect failures, fix remaining chart defects, rerun until green, and paste authentic command output into each entry. Commit the real session log. Never hand in this file unchanged as a completed Part 4.
