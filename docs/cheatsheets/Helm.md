# Helm Cheat Sheet (GitOps repo)

Validate and render charts locally.

- Lint charts
```bash
make lint
```

- Render templates (values per environment)
```bash
make render-dev
make render-qa
make render-prod
```

- Direct helm commands
```bash
helm lint charts/app-frontend
helm template frontend charts/app-frontend -f values/env/dev.yaml
```
