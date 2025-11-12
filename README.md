# aws-demo 项目结构

| 目录/文件 | 说明 |
|-----------|------|
| `src/` | Laravel 11 应用源码、Composer/NPM 依赖、`.env` 等，仅该目录需要被流水线打包部署。 |
| `infra/terraform` | Terraform 基础设施代码（VPC、ECS、RDS、AppConfig 等）。 |
| `.docker/` + `docker-compose.local.yml` | 本地开发运维脚本（PostgreSQL 容器等），不应进入应用包。 |
| `.github/`（如后续添加） | CI/CD 工作流定义。 |

## 开发者须知

1. **应用相关命令**：进入 `src` 目录再执行 `composer install`、`php artisan test/serve`、`npm run dev` 等。
2. **流水线打包**：只需压缩/构建 `src` 目录内容即可，避免将 `infra`、`.docker` 等运维配置带入镜像或发布包。
3. **基础设施**：Terraform 在 `infra/terraform`，运行命令前可在该目录下执行 `terraform init/plan/apply`。
4. **本地数据库**：如需使用容器化 PostgreSQL，运行 `docker compose -f docker-compose.local.yml up -d postgres`，凭证已在 `src/.env` 中对齐。

更多 Laravel 说明参考 `src/README.md`。
