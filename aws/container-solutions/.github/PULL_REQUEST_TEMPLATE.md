## Description

<!-- What does this PR do? Why is it needed? -->

## Type of Change

- [ ] New feature
- [ ] Bug fix
- [ ] Infrastructure change (Terraform)
- [ ] Kubernetes manifest change
- [ ] Helm chart change
- [ ] Documentation
- [ ] CI/CD pipeline change
- [ ] Chore / maintenance

## Environments Affected

- [ ] Dev
- [ ] Test
- [ ] Prod

## Testing Done

<!-- How was this tested? What commands were run? -->

```
# Example:
terraform plan -var-file=terraform.tfvars
helm lint helm/sample-app
kubectl apply --dry-run=client -f kubernetes/...
```

## Security Checklist

- [ ] No secrets, credentials, or account IDs hardcoded
- [ ] IAM changes follow least-privilege
- [ ] `tfsec` scan passed (or exceptions documented below)
- [ ] `checkov` scan passed (or exceptions documented below)
- [ ] Container images scanned for CVEs

## Pre-merge Checklist

- [ ] `terraform fmt -check` passes
- [ ] `terraform validate` passes
- [ ] `helm lint` passes (if Helm changes)
- [ ] Documentation updated
- [ ] ADR created/updated (if significant design decision)
- [ ] Runbook updated (if operational procedure changed)

## Scan Exceptions (if any)

<!-- If tfsec or checkov findings were suppressed, document the reason here -->

## Related Issues / Tickets

<!-- Link to Jira, GitHub Issues, or other references -->
