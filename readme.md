

# TerraVarTest

This repository contains Terraform configurations for deploying a two-tier web application on AWS. It uses modular infrastructure for reusability and best practices.

## What is a Two-Tier Web App?

A two-tier web application architecture separates the application into two main layers:

- **Tier 1: Web/Application Layer**
  - Handles user requests, runs application logic, and serves web pages.
  - Typically consists of EC2 instances behind a load balancer.

- **Tier 2: Data Layer**
  - Stores and manages data, usually in a database (e.g., RDS, MySQL, PostgreSQL).

This separation improves scalability, security, and maintainability. In this project, the web/app layer is deployed in private subnets, accessed via an Application Load Balancer in public subnets, while the data layer can be added or extended as needed.


## Recommended Structure for Multiple Environments

To manage separate environments (dev, staging, prod), use the following folder structure:

```
TerraVarTest/
  modules/
    vpc/
    alb/
    rds/
    # ...other reusable modules
  envs/
    dev/
      main.tf
      provider.tf
      backend.tf
      variables.tf
      # dev-specific values and module calls
    staging/
      main.tf
      provider.tf
      backend.tf
      variables.tf
      # staging-specific values and module calls
    prod/
      main.tf
      provider.tf
      backend.tf
      variables.tf
      # prod-specific values and module calls
  .gitignore
  README.md
```

**Explanation:**
- `modules/`: Contains all reusable infrastructure modules (VPC, ALB, RDS, etc.).
- `envs/`: Contains separate folders for each environment (`dev`, `staging`, `prod`).
  - Each environment folder has its own configuration files and can use different backend settings, variables, and module parameters.
  - You run `terraform init`, `plan`, and `apply` inside each environment folder independently.
- Root files: `.gitignore`, `README.md`, etc.

**Benefits:**
- Clean separation of environments.
- Easy to manage environment-specific settings and state.
- Reuse modules across all environments.

Refer to this structure for future expansion and best practices.

## Getting Started

1. **Install Terraform**
   - [Download Terraform](https://www.terraform.io/downloads.html) and install for your OS.

2. **Configure AWS Credentials**
   - Use `aws configure` or set environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`).

3. **Initialize Terraform**
   - Navigate to the working directory (e.g., `two_tier_web_app`) and run:
     ```sh
     terraform init
     ```

4. **Plan and Apply Infrastructure**
   - To see what will be created:
     ```sh
     terraform plan
     ```
   - To create resources:
     ```sh
     terraform apply
     ```

5. **Destroy Infrastructure**
   - To remove all managed resources:
     ```sh
     terraform destroy
     ```

## Remote State

Terraform state is stored in an S3 bucket (see `backend.tf`).
- Update `backend.tf` with your bucket name and region.
- (Optional) Use DynamoDB for state locking.

## Modules

Reusable modules are located in the `modules/` directory. Add new modules as needed for future services.

## Alternative: Terragrunt for Multi-Environment Management

Terragrunt is a popular wrapper for Terraform that simplifies managing multiple environments and reduces code duplication. It is recommended for larger or more complex infrastructure setups.

### Example Terragrunt Structure

```
TerraVarTest/
  modules/
    vpc/
    alb/
    rds/
  live/
    dev/
      terragrunt.hcl
    staging/
      terragrunt.hcl
    prod/
      terragrunt.hcl
  .gitignore
  README.md
```

**Key Features:**
- Centralizes backend and provider configuration.
- Supports inheritance and DRY principles using parent/child `terragrunt.hcl` files.
- Automates remote state, dependencies, and environment management.

**Sample `terragrunt.hcl` (dev environment):**
```hcl
include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules/vpc"
}

inputs = {
  name           = "dev-app"
  cidr_block     = "10.0.0.0/16"
  # ...other variables
}
```

**When to use Terragrunt:**
- Recommended for large teams, multi-account setups, or when you want to automate and standardize environment management.
- For small/medium projects, vanilla Terraform with separate folders is often sufficient.

Refer to [Terragrunt documentation](https://terragrunt.gruntwork.io/) for more details and advanced usage.

## .gitignore

Sensitive and state files are excluded from version control (see `.gitignore`).

## Notes
- Always review the plan before applying or destroying resources.
- Do not commit sensitive credentials to the repository.

---

For questions or improvements, open an issue or pull request.
