# Profile Board

Use IaC way to deploy a backend server on AWS EC2

## Architecture

The application is deployed on AWS using a secure, private VPC architecture with API Gateway for public access:

```mermaid
graph TB
    subgraph "Internet"
        Client[Client/Browser]
    end
    
    subgraph "AWS Cloud"
        subgraph "API Gateway"
            APIGW[API Gateway<br/>REST API]
            VPCLink[VPC Link]
        end
        
        subgraph "Custom VPC (10.0.0.0/16)"
            subgraph "Public Subnet (10.0.1.0/24)"
                IGW[Internet Gateway]
                NAT[NAT Gateway]
                EIP[Elastic IP]
            end
            
            subgraph "Private Subnet (10.0.2.0/24)"
                NLB[Network Load Balancer<br/>Internal]
                EC2[EC2 Instance<br/>Spring Boot App<br/>Port 8080]
                RDS[(PostgreSQL Database<br/>Port 5432)]
            end
            
            subgraph "Route Tables"
                PublicRT[Public Route Table]
                PrivateRT[Private Route Table]
            end
        end
        
        subgraph "ECR"
            ECRRepo[ECR Repository<br/>Docker Images]
        end
        
        subgraph "Security Groups"
            NLBSG[NLB Security Group<br/>Port 8080 from VPC]
            EC2SG[EC2 Security Group<br/>Port 8080 from NLB]
            DBSG[DB Security Group<br/>Port 5432 from EC2]
        end
        
        subgraph "IAM"
            EC2Role[EC2 IAM Role<br/>ECR Pull Permissions]
        end
    end
    
    Client -->|HTTPS Request| APIGW
    APIGW -->|/heartbeat| VPCLink
    VPCLink -->|HTTP| NLB
    NLB -->|Forward| EC2
    EC2 -->|Database Query| RDS
    EC2 -->|Pull Images| ECRRepo
    
    IGW -.->|Internet Access| NAT
    NAT -.->|Outbound Only| EC2
    
    PublicRT -.->|0.0.0.0/0| IGW
    PrivateRT -.->|0.0.0.0/0| NAT
    
    NLBSG -.->|Allows| NLB
    EC2SG -.->|Allows| EC2
    DBSG -.->|Allows| RDS
    EC2Role -.->|Attached| EC2
    
    classDef publicSubnet fill:#e1f5fe
    classDef privateSubnet fill:#f3e5f5
    classDef security fill:#fff3e0
    classDef database fill:#e8f5e8
    
    class IGW,NAT,EIP publicSubnet
    class NLB,EC2,RDS privateSubnet
    class NLBSG,EC2SG,DBSG,EC2Role security
    class RDS database
```

### Key Architecture Components:

- **API Gateway**: Provides public HTTPS endpoint (`/heartbeat`) with CORS support
- **VPC Link**: Securely connects API Gateway to private Network Load Balancer
- **Network Load Balancer**: Internal load balancer for high availability and health checks
- **EC2 Instance**: Runs Spring Boot application in private subnet (no public IP)
- **NAT Gateway**: Allows private subnet outbound internet access for Docker pulls
- **PostgreSQL RDS**: Database secured in private subnet, only accessible from EC2
- **ECR Repository**: Stores Docker images with proper IAM permissions
- **Security Groups**: Implement defense-in-depth with restrictive access rules

### Security Features:

- ✅ EC2 instance in private subnet (no direct internet access)
- ✅ Database isolated and only accessible from application
- ✅ Security groups with principle of least privilege
- ✅ IAM roles for service-to-service authentication
- ✅ HTTPS termination at API Gateway
- ✅ VPC Link for secure API Gateway integration

### Development

```bash
./gradlew ktlintFormat
```

```bash
./gradlew bootRun
```

```bash
auto/dev
```

```bash
docker build -t profile-board:latest .
```

```bash
docker run -p 8080:8080 profile-board:latest
```

## Kubernetes 部署

### 自动化部署脚本

使用 `auto/deploy-and-test.sh` 脚本可以一键部署应用到 Kubernetes 集群：

```bash
cd auto
./deploy-and-test.sh
```

该脚本会自动执行以下步骤：

1. 检查 kubectl 集群连接
2. 应用 Deployment 配置 (`k8s/development.yaml`)
3. 应用 Service 配置 (`k8s/service.yaml`)
4. 等待 Pod 就绪
5. 检查部署状态
6. 自动检测 K8s 环境类型（minikube/Docker Desktop）
7. 提供正确的访问 URL
8. 测试服务连通性

### 手动部署

如果需要手动部署，可以分步执行：

```bash
# 部署应用
kubectl apply -f k8s/development.yaml

# 创建服务
kubectl apply -f k8s/service.yaml

# 查看状态
kubectl get pods
kubectl get svc
kubectl logs <pod-name>
```

### 访问应用

部署完成后，根据你的 K8s 环境访问应用：

- **Minikube**: `http://<minikube-ip>:30080/heartbeat`
- **Docker Desktop**: `http://localhost:30080/heartbeat`
- **端口转发**:
  ```bash
  kubectl port-forward svc/profile-board-service 8080:8080
  # 然后访问 http://localhost:8080/heartbeat
  ```

## 推送镜像到 Docker Hub

1. 登录 Docker Hub：
   ```bash
   docker login
   ```
   按提示输入你的 Docker Hub 用户名和密码。

2. 给镜像打 tag（将 yourusername 替换为你的 Docker Hub 用户名）：
   ```bash
   docker tag profile-board:latest yourusername/profile-board:latest
   ```

3. 推送镜像到 Docker Hub：
   ```bash
   docker push yourusername/profile-board:latest
   ```

### Reference Documentation

For further reference, please consider the following sections:

* [Official Gradle documentation](https://docs.gradle.org)
* [Spring Boot Gradle Plugin Reference Guide](https://docs.spring.io/spring-boot/3.5.4/gradle-plugin)
* [Create an OCI image](https://docs.spring.io/spring-boot/3.5.4/gradle-plugin/packaging-oci-image.html)
* [Spring Data JPA](https://docs.spring.io/spring-boot/3.5.4/reference/data/sql.html#data.sql.jpa-and-spring-data)
* [Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)

### Guides

The following guides illustrate how to use some features concretely:

* [Accessing Data with JPA](https://spring.io/guides/gs/accessing-data-jpa/)

### Additional Links

These additional references should also help you:

* [Gradle Build Scans – insights for your project's build](https://scans.gradle.com#gradle)
