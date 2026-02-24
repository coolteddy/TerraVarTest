# Terragrunt DRY Config Test

Simple example to demonstrate Terragrunt's DRY inheritance pattern using SSM Parameters across environments.

## Structure

```
terragrunt-test/
├── root.hcl                          # Root config: remote state + provider (inherited by all envs)
├── environments/
│   ├── dev/
│   │   └── terragrunt.hcl           # Dev-specific inputs
│   └── prod/
│       └── terragrunt.hcl           # Prod-specific inputs
└── modules/
    └── ssm-parameter/               # Reusable Terraform module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/)
- AWS CLI with SSO configured

## Usage

### 1. Login to AWS SSO

```bash
aws sso login --profile <your-aws-profile>
```

### 2. Set your AWS profile

```bash
export AWS_PROFILE=<your-aws-profile>
```

### 3. First-time run — auto-provision the S3 remote state bucket

On the very first run, Terragrunt will detect that the S3 state bucket does not exist and prompt you to create it. Use the command below to automatically answer `y` and provision it:

```bash
cd environments/dev
echo "y" | terragrunt plan --backend-bootstrap
```

> **Note:** You only need `echo "y" | ... --backend-bootstrap` once. After the S3 bucket is created, use the standard commands below for all future runs.

### 4. Standard plan and apply (after first-time setup)

**Dev:**
```bash
cd environments/dev
terragrunt plan
terragrunt apply
```

**Prod:**
```bash
cd environments/prod
terragrunt plan
terragrunt apply
```

### 5. Destroy

```bash
cd environments/dev
terragrunt destroy
```

## How DRY Works Here

- `root.hcl` defines the S3 remote state backend and AWS provider **once**
- Each environment's `terragrunt.hcl` uses `include "root"` to inherit everything
- Only the inputs (param name, value, env tag) differ per environment
- No duplicated backend or provider blocks anywhere

---

## TODO — Multi-Account Setup (dev + prod accounts)

The current setup uses a single AWS account. The plan below extends it to two accounts (dev and prod), each with its own state bucket and AWS SSO profile.

### Prerequisites
- [ ] Add `dev-account` and `prod-account` profiles in AWS IAM Identity Center
- [ ] Update `~/.aws/config` with friendly profile names pointing to each account
- [ ] Verify both profiles work: `aws sts get-caller-identity --profile dev-account`

### Folder Structure Changes
```
terragrunt-test/
├── root.hcl                          # Update to read account.hcl
└── environments/
    ├── dev/
    │   ├── account.hcl               # new — dev profile + region
    │   └── terragrunt.hcl
    └── prod/
        ├── account.hcl               # new — prod profile + region
        └── terragrunt.hcl
```

### Code Changes

**1. Create `environments/dev/account.hcl`**
```hcl
locals {
  aws_profile = "dev-account"
  region      = "eu-west-2"
}
```

**2. Create `environments/prod/account.hcl`**
```hcl
locals {
  aws_profile = "prod-account"
  region      = "eu-west-2"
}
```

**3. Update `root.hcl`** to read `account.hcl` and pass profile to provider:
```hcl
locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  aws_profile  = local.account_vars.locals.aws_profile
  region       = local.account_vars.locals.region
  account_id   = get_aws_account_id()
}
```

### How It Works After Changes
- `cd environments/dev` → reads `dev/account.hcl` → uses `dev-account` profile → state bucket: `terragrunt-state-<dev-account-id>`
- `cd environments/prod` → reads `prod/account.hcl` → uses `prod-account` profile → state bucket: `terragrunt-state-<prod-account-id>`
- No manual profile switching needed — fully automatic per environment
