# Terraform 基础结构

该目录集中管理 AWS 基础设施（VPC、ECS、RDS、AppConfig 等）。目前已完成 Step 1（网络）和 Step 2（ECR），后续可继续扩展。

## 文件说明
| 文件 | 作用/创建的资源 |
|------|----------------|
| `main.tf` | Terraform 与 AWS Provider 版本约束，加载 `var.aws_region` 指定区域。 |
| `variables.tf` | 统一维护 `project_name`、`environment`、`vpc_cidr`、`az_count`、`flow_logs_retention_days` 等变量。 |
| `locals.tf` | 生成 `name_prefix`、公共标签、自动选择可用区并计算公/私子网 CIDR，提供 Caller Identity、Region、AZ 数据。 |
| `network.tf` | **Step 1**：创建 VPC、IGW、每 AZ 公/私子网、NAT 网关、路由表及关联，并配置 CloudWatch Log Group + IAM 角色 + VPC Flow Logs。 |
| `ecr.tf` | **Step 2**：创建应用镜像专用 ECR 仓库，开启推送扫描、AES256 加密，并配置 14 天自动清理未打标签镜像的生命周期策略。 |
| `security.tf` | 定义 ALB 与 ECS 任务的安全组，限制入口来源并仅允许 ALB 访问容器端口。 |
| `alb.tf` | **Step 3**：创建公网 ALB、Target Group 及 HTTP Listener，为 ECS 服务提供入口流量。 |
| `ecs.tf` | **Step 3**：创建 ECS Cluster、任务执行/Task IAM 角色、CloudWatch Log Group、Fargate Task Definition、Service 以及 17:00–17:59 JST 的定时扩缩容。 |
| `rds.tf` | **Step 4（进行中）**：创建 PostgreSQL RDS（私网、多日志导出）、专用安全组、子网组，以及存放 `pg_dump` 的 S3 Bucket（默认 30 天生命周期）。 |
| `outputs.tf` | 汇总 VPC ID、子网 ID、NAT IDs、Flow Log Group、ECR 仓库名称/URI 等输出，供后续模块引用或文档使用。 |
| `.terraform.lock.hcl` | Provider 锁文件，确保团队使用一致版本。 |

## 操作步骤
1. **设置 AWS 凭证**  
   - 推荐使用 AWS CLI Profile：`$env:AWS_PROFILE="poper-devops"`（PowerShell）或 `export AWS_PROFILE=poper-devops`（bash）。  
   - 执行 `aws sts get-caller-identity` 验证凭证无误。

2. **初始化**  
   ```powershell
   cd infra/terraform
   terraform init
   ```
   首次会下载 provider 并生成 `.terraform.lock.hcl`。若改用远程状态（S3 + DynamoDB），在 `terraform` 块添加 `backend "s3"` 后需 `terraform init -reconfigure`。

3. **规划 / 应用**  
   默认配置会在 `ap-northeast-1` 创建 `10.20.0.0/16` VPC、2 个 AZ。可通过 `-var` 覆盖：
   ```powershell
   terraform plan -var="project_name=poper-devops" -var="environment=dev"
   terraform apply -var="project_name=poper-devops" -var="environment=dev"
   ```
   `apply` 输出中包含 VPC、子网、NAT、Flow Log、ECR 的详细信息，请保存以备文档使用。

4. **销毁**  
   ```powershell
   terraform destroy
   ```
   *在销毁前确认没有其他资源依赖该 VPC/ECR（如 ECS、RDS、CI/CD），否则会失败。*

## 下一步建议
- 新建 `modules/`（如 `ecs`, `alb`, `rds`, `appconfig`, `monitoring`）并按环境拆分。  
- 配置远程状态（S3 + DynamoDB）与 `terraform.tfvars`，保证团队协同。  
- 将 Terraform 命令封装为脚本或 Makefile，方便流水线调用。
