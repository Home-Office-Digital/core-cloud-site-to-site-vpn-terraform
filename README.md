# core-cloud-site-to-site-vpn-terraform

## Directory Structure

```plaintext
modules/
├── private-subnets/
│   ├── data.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── tests/
│   │   └── private-subnets.tftest.hcl
│   ├── variables.tf
│   ├── versions.tf
│   └── README.md
└── site-to-site-vpn/
	├── firsvpn/
	│   ├── data.tf
	│   ├── main.tf
	│   ├── outputs.tf
	│   ├── tests/
	│   │   └── firsvpn.tftest.hcl
	│   ├── variables.tf
	│   └── versions.tf
	└── generic-vpn/
		├── data.tf
		├── main.tf
		├── outputs.tf
		├── tests/
		│   └── generic-vpn.tftest.hcl
		├── variables.tf
		└── versions.tf
```

## Testing

This repository uses native `terraform test` files stored under each module's `tests/` directory.

Run tests locally from the module root:

```bash
terraform -chdir=modules/private-subnets init -backend=false
terraform -chdir=modules/private-subnets test

terraform -chdir=modules/site-to-site-vpn/firsvpn init -backend=false
terraform -chdir=modules/site-to-site-vpn/firsvpn test

terraform -chdir=modules/site-to-site-vpn/generic-vpn init -backend=false
terraform -chdir=modules/site-to-site-vpn/generic-vpn test
```

The GitHub Actions workflow discovers module-local `.tftest.hcl` files under `modules/**/tests/` and runs `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, and `terraform test` for each discovered module.
