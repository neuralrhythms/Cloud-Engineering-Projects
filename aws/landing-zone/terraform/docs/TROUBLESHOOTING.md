# Troubleshooting Guide

Common issues, their root causes, and resolutions.

---

## Terraform Errors

### State Lock Errors

**Symptom:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Path:      landing-zone-terraform-state-.../terraform.tfstate
  Operation: OperationTypeApply
```

**Cause:** A previous Terraform run was interrupted or crashed without releasing the lock.

**Resolution:**
```bash
# Verify no other operations are running
# Then force-unlock
terraform force-unlock xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Prevention:** Never interrupt `terraform apply` with Ctrl+C. If needed, wait for it to reach a safe point.

---

### Backend Configuration Errors

**Symptom:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist.
```

**Cause:** The `ACCOUNT_ID` placeholder in backend configuration hasn't been replaced.

**Resolution:**
```bash
# Find all placeholders
grep -r "ACCOUNT_ID" layers/

# Replace with actual Management Account ID
# Edit each layers/*/main.tf backend block
```

---

### Provider Authentication Errors

**Symptom:**
```
Error: error configuring Terraform AWS Provider: no valid credential sources found
```

**Cause:** AWS credentials not configured or expired.

**Resolution:**
```bash
# Check current identity
aws sts get-caller-identity

# If using SSO profiles
aws sso login --profile your-profile

# If using environment variables
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_REGION=us-east-1
```

---

### Assume Role Errors

**Symptom:**
```
Error: error assuming role: AccessDenied: User: arn:aws:iam::111...:user/terraform 
is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::222...:role/OrganizationAccountAccessRole
```

**Cause:** The role trust policy doesn't include the calling principal, or an SCP is blocking.

**Resolution:**
1. Verify the role exists in the target account
2. Check the trust policy allows the calling account
3. Check for SCPs that might deny `sts:AssumeRole`
4. Verify the Management Account's root or admin can assume the role

```bash
# Test the assume-role manually
aws sts assume-role \
  --role-arn arn:aws:iam::<TARGET>:role/OrganizationAccountAccessRole \
  --role-session-name test
```

---

### Resource Already Exists

**Symptom:**
```
Error: error creating Organization: AlreadyInOrganizationException: 
The AWS account is already a member of an organization.
```

**Cause:** The resource was created outside Terraform or in a previous run that wasn't tracked.

**Resolution:**
```bash
# Import the existing resource
terraform import aws_organizations_organization.this o-xxxxxxxxxx

# Then plan to verify state matches reality
terraform plan
```

---

## AWS Organization Errors

### Account Email Already In Use

**Symptom:**
```
Error: error creating Organization Account: ConstraintViolationException: 
The email address is already associated with another AWS account.
```

**Cause:** Each AWS account globally requires a unique email address.

**Resolution:**
- Use a different email address
- Use plus-addressing: `aws+unique-suffix@company.com`
- If the email is from a closed account, AWS Support can release it

---

### SCP Lockout

**Symptom:** Cannot perform any actions in a member account, even as admin.

**Cause:** An overly restrictive SCP is denying all actions.

**Resolution:**
1. Go to the **Management Account** (SCPs don't apply to it)
2. Identify the problematic SCP:
   ```bash
   aws organizations list-policies-for-target \
     --target-id <ACCOUNT_ID_OR_OU_ID> \
     --filter SERVICE_CONTROL_POLICY
   ```
3. Detach the SCP:
   ```bash
   aws organizations detach-policy \
     --policy-id p-xxxxxxxx \
     --target-id ou-xxxx-xxxxxxxx
   ```
4. Fix the SCP policy content, then reattach

**Prevention:** Always test SCPs in the Sandbox OU first.

---

### Account Creation Limit

**Symptom:**
```
Error: ConstraintViolationException: You have exceeded the allowed number of AWS accounts.
```

**Cause:** AWS Organizations has a default limit of 10 accounts. Must be increased.

**Resolution:**
1. Request a quota increase via AWS Support
2. Go to Service Quotas → AWS Organizations → "Default maximum number of accounts"
3. Typical increases: 50, 100, 500+ are routinely granted

---

## Network Errors

### TGW Attachment Not Propagating

**Symptom:** VPCs can't communicate even though TGW attachments exist.

**Cause:** Missing route table associations, propagations, or VPC routes.

**Diagnosis:**
```bash
# Check TGW route table associations
aws ec2 get-transit-gateway-route-table-associations \
  --transit-gateway-route-table-id tgw-rtb-xxxxxxxx

# Check TGW routes
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id tgw-rtb-xxxxxxxx \
  --filters "Name=type,Values=propagated,static"

# Check VPC route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxxxxxxx"
```

**Resolution:**
1. Verify the TGW attachment is in state "available"
2. Ensure route table association exists for the attachment
3. Add route propagation or static routes as needed
4. Ensure VPC route tables have a route to TGW for the desired destinations

---

### No Internet Access from Workload VPC

**Symptom:** EC2 instances in workload VPCs can't reach the internet.

**Diagnosis path:**
```
Instance → VPC Route Table → TGW → Edge Route Table → Egress VPC → NAT GW → IGW → Internet
```

**Check each hop:**
```bash
# 1. VPC route table has 0.0.0.0/0 → TGW
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxx"

# 2. TGW route table has 0.0.0.0/0 → egress attachment
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id <PROD_RT_ID> \
  --filters "Name=route-search.exact-match,Values=0.0.0.0/0"

# 3. Egress VPC route table has 0.0.0.0/0 → NAT GW
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<EGRESS_VPC_ID>"

# 4. NAT GW is in "available" state
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<EGRESS_VPC_ID>"

# 5. Security groups allow outbound traffic
aws ec2 describe-security-groups --group-ids <SG_ID>
```

---

### RAM Share Not Accepted

**Symptom:** TGW not visible in workload accounts.

**Cause:** Auto-accept may not be working or RAM sharing isn't enabled for the org.

**Resolution:**
```bash
# Enable RAM sharing in the Organization
aws ram enable-sharing-with-aws-organization --profile landing-zone-mgmt

# Verify the share status
aws ram get-resource-shares --resource-owner OTHER-ACCOUNTS --profile workload-account
```

---

## Security Service Errors

### GuardDuty Member Account Not Enrolled

**Symptom:** New accounts not appearing in GuardDuty member list.

**Cause:** Organization auto-enable may not have triggered yet, or account was created before GuardDuty was configured.

**Resolution:**
```bash
# Manually create the member from the delegated admin account
aws guardduty create-members \
  --detector-id <DETECTOR_ID> \
  --account-details AccountId=<NEW_ACCOUNT_ID>,Email=<EMAIL> \
  --profile security-account
```

---

### Security Hub Finding Import Failures

**Symptom:** Findings not appearing from certain integrations.

**Diagnosis:**
```bash
# Check enabled integrations
aws securityhub list-enabled-products-for-import --profile security-account

# Check if the integration is enabled
aws securityhub describe-products --profile security-account
```

**Resolution:**
```bash
# Enable the product integration
aws securityhub enable-import-findings-for-product \
  --product-arn arn:aws:securityhub:us-east-1::product/aws/guardduty \
  --profile security-account
```

---

### Config Recorder Not Recording

**Symptom:** Config shows "No data" for resources.

**Diagnosis:**
```bash
aws configservice describe-configuration-recorder-status --profile <account>
```

**Resolution:**
If status shows `recording: false`:
```bash
aws configservice start-configuration-recorder \
  --configuration-recorder-name default \
  --profile <account>
```

Check that the delivery channel S3 bucket policy allows writes from the account.

---

## CI/CD Pipeline Errors

### OIDC Authentication Failure

**Symptom:**
```
Error: Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Cause:** The OIDC trust policy doesn't match the calling repository or branch.

**Resolution:**
1. Verify the trust policy condition matches your repo:
   ```json
   "token.actions.githubusercontent.com:sub": "repo:YOUR-ORG/YOUR-REPO:*"
   ```
2. Check the OIDC provider thumbprint is current
3. Ensure the audience is `sts.amazonaws.com`

---

### Plan Shows Unexpected Changes

**Symptom:** Plan wants to modify resources that shouldn't have changed.

**Common Causes:**
- Provider version upgrade changed default values
- AWS service update changed resource schema
- Someone made manual changes in the console

**Resolution:**
```bash
# See what's different
terraform plan -detailed-exitcode

# If caused by manual changes, either:
# 1. Apply to revert manual changes
terraform apply

# 2. Or import current state to accept manual changes
terraform refresh
```

---

## Performance Issues

### Slow Terraform Plans

**Cause:** Large state files, many API calls.

**Resolution:**
- Use `-refresh=false` if you trust the state (planning only)
- Increase parallelism: `-parallelism=20`
- Split large layers into smaller state files
- Use targeted plans for specific resources: `-target=module.vpc`

---

### API Throttling

**Symptom:**
```
Error: error reading ... ThrottlingException: Rate exceeded
```

**Resolution:**
- Reduce parallelism: `-parallelism=5`
- Add retry logic via provider configuration:
  ```hcl
  provider "aws" {
    retry_mode  = "adaptive"
    max_retries = 10
  }
  ```
- Wait and retry (often caused by hitting account-level API limits)

---

## Getting Support

1. **This repository**: Open a GitHub Issue with the error details
2. **AWS Support**: For service-specific issues (requires Business or Enterprise plan)
3. **HashiCorp**: For Terraform-specific bugs (GitHub Issues)
4. **Community**: AWS re:Post, HashiCorp Discuss forums
