# Virtuoso Self-managed OpenTofu Deployments

Self-managed OpenTofu deployment scripts for OpenLink Virtuoso Universal Server across supported cloud providers.

This repository is for **self-managed** deployments only. It does not contain the managed SaaS control plane, Marketplace integration, customer portal, seller admin portal, or operational evidence used by the managed service.

Repository remote:

- `https://github.com/OpenLinkSoftware/virtuoso-opentofu`

Primary purpose:

- Deploy single self-managed Virtuoso instances on supported cloud providers.
- Provide a consistent OpenTofu-based deployment workflow across AWS, Azure, and Google Cloud.
- Support both Virtuoso Open Source 7 and Virtuoso Commercial 8 images where documented by the provider-specific deployment.

## Supported Providers

| Provider | Status | Directory |
|---|---|---|
| AWS | Available | [`aws/`](aws/) |
| Azure | Available | [`azure/`](azure/) |
| Azure ACI | Experimental | [`azure/aci/`](azure/aci/) |
| Google Cloud | Available | [`gcp/`](gcp/) |

Current scope by provider:

- `aws/`: ECS Fargate + EFS based self-managed deployment.
- `azure/`: Azure Virtual Machine + Managed Disk based recommended Azure self-managed baseline.
- `azure/aci/`: Azure Container Instances + Azure Files based experimental baseline. Functional for light tests, but local SQL benchmarking on August 18, 2026 showed unacceptable active-database latency even with Premium Azure Files.
- `gcp/`: Compute Engine + Docker + Persistent Disk + Secret Manager based self-managed deployment.

All deployments generate a DBA password that is present in OpenTofu state. Configure an encrypted remote backend before production use; see [`docs/REMOTE_STATE.md`](docs/REMOTE_STATE.md). Pin production container images to a tested release tag or immutable digest rather than `latest`.

## Usage

Choose the cloud provider directory and run OpenTofu from inside that directory.

For AWS:

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars as needed
tofu init
tofu validate
tofu plan
tofu apply
```

Each provider directory is intentionally self-contained, with its own `README.md`, `versions.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, deployment helper script, and provider-specific modules.

Multiple deployments are supported within the same cloud account, subscription, or project. The requirement is separate OpenTofu state per deployment plus a distinct naming prefix such as `project_name`.

Use the provider-specific READMEs for:

- prerequisites
- supported architecture
- image and license handling
- backup and restore workflow
- shell/container access
- multi-deployment patterns
- cleanup and destroy guidance

## Future Variants

Potential future additions under consideration:

- `azure/aks/`: Kubernetes-based Azure self-managed variant using AKS with Azure Disk for the live database volume
- `gcp/gke/`: Kubernetes-based Google Cloud self-managed variant using GKE with Persistent Disk for the live database volume

These are future options only. The current recommended single-instance self-managed baselines remain:

- `azure/`: Azure VM + Managed Disk
- `gcp/`: Compute Engine + Persistent Disk

## Repository Layout

```text
virtuoso-opentofu/
├── README.md
├── .gitignore
├── aws/
│   ├── README.md
│   ├── deploy.sh
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       └── virtuoso-server/
├── azure/
│   ├── README.md
│   ├── deploy.sh
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── terraform.tfvars.example
│   ├── modules/
│   │   └── virtuoso-server/
│   └── aci/
│       ├── README.md
│       ├── deploy.sh
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── terraform.tfvars.example
│       ├── modules/
│       │   └── virtuoso-server/
│       └── scripts/
└── gcp/
    ├── README.md
    ├── deploy.sh
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    ├── terraform.tfvars.example
    └── modules/
        └── virtuoso-server/
```

## Publishing Boundary

Do not add managed SaaS implementation files to this repository. Managed SaaS code should remain in the private/full development repository.

Excluded by design:

- AWS Marketplace SaaS registration and metering code
- Customer and seller portal source code
- Managed SaaS control-plane Lambda/API/CodeBuild/OpenTofu code
- Marketplace private offer JSON files
- Marketplace validation evidence
- Terraform/OpenTofu state files and local `terraform.tfvars`

This repository is intended to be understandable to operators who only want to deploy and manage self-hosted Virtuoso infrastructure and do not need any of the AWS Marketplace managed-service implementation.
