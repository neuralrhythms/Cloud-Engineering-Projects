# CI/CD Pipeline Setup Guide

Complete instructions for configuring the GitHub Actions CI/CD pipeline.

---

## Overview

The pipeline automates Terraform operations:

| Workflow | Trigger | Action |
|----------|---------|--------|
| `terraform-plan.yml` | Pull request to `main` | Runs plan, posts output as PR comment |
| `terraform-apply.yml` | Push/merge to `main` | Applies changes sequentially by layer |
| `drift-detection.yml` | Cron (weekday 6 AM UTC) | Detects configuration drift, creates Issues |

---

## Step 1: GitHub OIDC Authentication

The pipeline authenticates to AWS using OpenID Connect (OIDC) - no stored secrets needed.

### What OIDC Does

Instead of storing AWS access keys as GitHub secrets, the pipeline:
1. Requests a short-lived JWT token from GitHub
2. Presents this token to AWS STS
3. AWS validates the token against the registered OIDC provider
4. AWS returns temporary credentials (valid 1 hour)

### Prerequisites

The OIDC provider and IAM role are created in Layer 00 (Bootstrap):

```bash
cd layers/00-bootstrap
terraform apply \
  -var="enable_github_oidc=true" \
  -var="github_org=your-org-name" \
  -var="github_repo=aws-landing-zone"
```

This creates:
- An IAM OIDC provider for `token.actions.githubusercontent.com`
- An IAM role `github-actions-terraform` with trust policy scoped to your repo

### Note the Role ARN

```bash
terraform output github_oidc_role_arn
# Example: arn:aws:iam::123456789012:role/github-actions-terraform
```

---

## Step 2: GitHub Repository Configuration

### Repository Variables

Go to **Settings → Secrets and variables → Actions → Variables**:

| Variable Name | Value | Description |
|--------------|-------|-------------|
| `AWS_OIDC_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-actions-terraform` | IAM role for OIDC auth |

### Environments

Go to **Settings → Environments**:

1. Create an environment named `production`
2. Add **Required reviewers** (platform team members)
3. Optionally add deployment branch rules (only allow `main`)

This gates the apply workflow - merges to main trigger a plan, but apply requires manual approval.

### Branch Protection Rules

Go to **Settings → Branches → Add rule** for `main`:

- [x] Require a pull request before merging
- [x] Require approvals (1 minimum, 2 for security layers)
- [x] Require status checks to pass: `plan`
- [x] Require conversation resolution before merging
- [x] Do not allow bypassing the above settings

---

## Step 3: CODEOWNERS

The `.github/CODEOWNERS` file enforces team-based review:

```
# Default: platform team reviews everything
* @platform-engineering-team

# Security changes require security team
/layers/01-organization/ @security-team @platform-engineering-team
/layers/02-security/     @security-team @platform-engineering-team
/policies/               @security-team @platform-engineering-team

# Network changes require network team
/layers/04-networking/   @network-team @platform-engineering-team
/modules/vpc/            @network-team
/modules/transit-gateway/ @network-team
```

Enable "Require review from Code Owners" in branch protection rules.

---

## Step 4: Workflow Details

### Plan Workflow (`terraform-plan.yml`)

Triggered on: PRs targeting `main` that modify infrastructure code.

**What it does:**
1. Detects which layers were affected by the PR
2. Runs `terraform init`, `validate`, `fmt -check` per affected layer
3. Runs `terraform plan` per affected layer
4. Posts plan output as a PR comment
5. Runs security scans (tfsec, checkov)

**Interpreting plan output:**
- `Plan: X to add, Y to change, Z to destroy` — normal, review changes
- Format check failures — run `terraform fmt -recursive` locally
- Validate failures — syntax errors in HCL code
- Security scan warnings — review for false positives, suppress or fix

### Apply Workflow (`terraform-apply.yml`)

Triggered on: Pushes to `main` (after PR merge).

**What it does:**
1. Runs layers sequentially (`max-parallel: 1`)
2. Fails fast if any layer errors
3. Requires `production` environment approval

**Sequential execution** ensures layers are applied in dependency order (organization before security before networking, etc.).

### Drift Detection (`drift-detection.yml`)

Triggered on: Cron schedule (weekdays at 6 AM UTC) or manual dispatch.

**What it does:**
1. Runs `terraform plan -detailed-exitcode` per layer
2. Exit code 2 means drift detected
3. Creates a GitHub Issue with the drift details
4. Labels the issue with `drift` and `infrastructure`

---

## Step 5: Cross-Account Access

The OIDC role in the Management Account needs permission to assume roles in member accounts.

### IAM Role Chain

```
GitHub Actions → OIDC → Management Account Role → Assume Role → Member Account Role
```

The `github-actions-terraform` role needs a policy allowing `sts:AssumeRole` for all member accounts:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::*:role/OrganizationAccountAccessRole"
    }
  ]
}
```

This is already included when the bootstrap gives `AdministratorAccess`. For tighter security, scope it to specific account IDs.

---

## Step 6: Testing the Pipeline

### First PR Test

1. Create a branch:
   ```bash
   git checkout -b test/verify-pipeline
   ```

2. Make a minor change (e.g., add a tag):
   ```bash
   echo "" >> layers/01-organization/main.tf
   ```

3. Push and open a PR:
   ```bash
   git push -u origin test/verify-pipeline
   ```

4. Verify:
   - Plan workflow triggers
   - Plan output appears as PR comment
   - Security scans complete

5. Merge the PR and verify:
   - Apply workflow triggers
   - Environment approval gate activates
   - After approval, apply succeeds

### Manual Drift Check

```bash
# Trigger drift detection manually
gh workflow run drift-detection.yml
```

---

## Advanced Configuration

### Parallel Execution for Independent Layers

If your layers are independent (not the default), you can enable parallel apply:

```yaml
# In terraform-apply.yml
strategy:
  max-parallel: 3  # Careful: only if layers are truly independent
```

### Slack/Teams Notifications

Add a notification step after apply:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1.25.0
  with:
    channel-id: 'C0XXXXXXXXX'
    slack-message: "Layer ${{ matrix.layer }}: ${{ job.status }}"
  env:
    SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

### Plan Artifacts

Store plan files for exact apply:

```yaml
- name: Save Plan
  run: terraform plan -out=tfplan
  
- name: Upload Plan
  uses: actions/upload-artifact@v4
  with:
    name: plan-${{ matrix.layer }}
    path: layers/${{ matrix.layer }}/tfplan

# In apply job:
- name: Download Plan
  uses: actions/download-artifact@v4
  with:
    name: plan-${{ matrix.layer }}
    
- name: Apply Saved Plan
  run: terraform apply tfplan
```

### Cost Estimation

Add Infracost for cost impact on PRs:

```yaml
- name: Setup Infracost
  uses: infracost/actions/setup@v3
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate Cost Diff
  run: |
    infracost diff \
      --path layers/${{ matrix.layer }} \
      --format json \
      --out-file /tmp/infracost.json

- name: Post Cost Comment
  uses: infracost/actions/comment@v3
  with:
    path: /tmp/infracost.json
    behavior: update
```

---

## Security Considerations

### Principle of Least Privilege

The default setup gives the OIDC role `AdministratorAccess`. For production:

1. Create a scoped policy that only allows Terraform-needed actions
2. Use separate roles per layer (different permission sets)
3. Scope the OIDC trust to specific branches:
   ```json
   "token.actions.githubusercontent.com:sub": "repo:org/repo:ref:refs/heads/main"
   ```

### Protecting Sensitive State

Terraform state may contain secrets. Ensure:
- State bucket has strict bucket policy
- KMS encryption is mandatory
- Access logging enabled on the state bucket
- Versioning for rollback capability

### Audit Trail

All CI/CD actions are logged in:
- GitHub Actions run history
- AWS CloudTrail (API calls made by the OIDC role)
- DynamoDB lock table (who ran what, when)
