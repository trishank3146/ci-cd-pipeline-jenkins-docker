# Optional: deploying to AWS (ECR + EC2)

The pipeline always deploys locally. If you tick **DEPLOY_TO_AWS** when starting a build (**Build with Parameters**), it also pushes the Docker image to **Amazon ECR** and runs it on an **Amazon EC2** server, using the same `deploy.sh` health check and automatic rollback.

```
Jenkins ──docker push──► Amazon ECR (image registry)
   │                          │
   └──ssh──► Amazon EC2 ──docker pull──┘ ──► deploy.sh (health check + rollback)
```

> AWS charges for resources. A `t2.micro` / `t3.micro` EC2 instance is covered by the AWS Free Tier for new accounts. Stop or terminate it when you're done.

## 1. Create an ECR repository

AWS Console → **ECR** → **Create repository** → name: `task-manager-api`.
Copy the registry address, for example `123456789012.dkr.ecr.ap-south-1.amazonaws.com`.

## 2. Launch an EC2 server

1. **EC2 → Launch instance** → Amazon Linux 2023, `t3.micro`, create or choose a key pair (download the `.pem` file).
2. **Security group:** allow SSH (22) from your IP and TCP **8081** for the app.
3. **IAM role:** attach a role with the policy **AmazonEC2ContainerRegistryReadOnly**, so the server can pull images without storing keys.
4. **User data** (installs Docker on first boot):

```bash
#!/bin/bash
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
```

## 3. Create an IAM user for Jenkins

IAM → Users → Create user `jenkins-ci` → attach **AmazonEC2ContainerRegistryPowerUser** → create an **access key**.

## 4. Add credentials to Jenkins

Manage Jenkins → **Credentials** → System → Global → **Add credentials**:

| Kind | ID | Values |
|---|---|---|
| Username with password | `aws-credentials` | Username = access key ID, Password = secret access key |
| SSH Username with private key | `ec2-ssh-key` | Username = `ec2-user`, Private key = contents of the `.pem` file |

Credentials live only in Jenkins and are never committed to Git.

## 5. Run it

Open the job → **Build with Parameters** → tick **DEPLOY_TO_AWS** → fill in `ECR_REGISTRY`, `AWS_REGION` (default `ap-south-1`, Mumbai) and `EC2_HOST` (the server's public IP) → **Build**.

When it finishes, open `http://<EC2_HOST>:8081/api/version` to see the build number running on AWS.
