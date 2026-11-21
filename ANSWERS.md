# Q1 — Migrating ~40 ingress-nginx Ingresses to Gateway API without downtime

I would treat this as a traffic migration, not a bulk YAML conversion.

1. **Inventory and dependencies:** export the 40 Ingresses, DNS records, certificates, annotations, rewrites, auth, session affinity, timeouts, WebSockets, rate limits, and external integrations. Baseline error rate, latency, request volumes, and known long-lived connections.
2. **Pick and validate a supported Gateway controller:** compare required features against its Gateway API conformance and implementation-specific policies. Install Gateway API CRDs and the new controller alongside ingress-nginx; retain existing traffic paths. Define `GatewayClass`, `Gateway`, listeners, `HTTPRoute`s, and `ReferenceGrant`s where cross-namespace references are needed.
3. **Prove parity first:** test routing, TLS/SNI, redirects, rewrites, backend health, mTLS/auth, observability, and rollback in staging. In production, point a test hostname or canary traffic at the new controller before touching the old DNS.
4. **Migrate progressively:** shift one low-risk application, then groups of routes using weighted DNS or load-balancer traffic splitting with health checks and low DNS TTLs. Maintain both controllers during propagation. Validate 4xx/5xx, p95 latency, and certificates after every wave; halt automatically on regressions.
5. **Rollback and retire:** keep old routes and TLS secrets available. On failure, restore traffic weights/DNS to the old ingress and investigate. After sustained monitoring and DNS/cache expiry, remove old routes, controller, CRDs only if unused, and obsolete policies.

**Expected breaks:** nginx-specific annotations have no one-to-one mapping; regex/path rewrites and header handling may change; backend protocol/TLS, client-IP preservation, sticky sessions, WebSocket timeouts, certificate ownership, and cross-namespace permissions need explicit tests. Gateway API alone does not provide these features uniformly; controller capabilities determine the migration plan.
