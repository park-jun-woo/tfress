# tfress

Terraform‑powered, serverless news CMS  
S3 + CloudFront static site with versioned articles and a journalist → editor approval workflow.

---

**🔔 Acknowledgements:** [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)  
**📜 Notice & Licenses:** [NOTICE](NOTICE)

---

> ⚠️ **Work In Progress:**  
> This project is not yet complete—use at your own risk!

---

## Features

- **Serverless frontend** on S3 + CloudFront  
- **Article versioning** with draft & publish buckets  
- **Approval workflow**: Journalist → Editor → Admin  
- **Cognito‑backed authentication** for protected admin UI  
- **Signed‑cookie support** for fine‑grained CloudFront access control

## Quickstart

1. Clone the repo  
   ```bash
   git clone https://github.com/your‑org/tfress.git
   cd tfress/infra
   ```
2. Configure your variables in `/terraform/env/backend.tfvars`
   ```bash
   bucket  = "apaya-terraform-bucket"
   key     = "tfress/infra.tfstate"
   region  = "ap-northeast-2"
   encrypt = true
   ```
3. Configure your variables in `terraform/env/dev.tfvars`
4. Initialize & apply  
   ```bash
   terraform init -backend-config=./env/backend.tfvars
   terraform workspace new dev    # or select existing workspace
   terraform apply
   ```
5. Deploy your frontend builds and Lambda code as described in the **CI** folder.

## License

This project is licensed under the terms described in [NOTICE](NOTICE).  
