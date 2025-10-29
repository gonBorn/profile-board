# Profile Board

## Development

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

## Push image to Docker Hub or ECR

1. 登录 Docker Hub：
   ```bash
   docker login
   ```
   or ecr: 
    ```bash
   aws ecr get-login-password --region ap-southeast-2 --profile PowerUserPlusRole-160071257600 \
   | docker login \
   --username AWS \
   --password-stdin 160071257600.dkr.ecr.ap-southeast-2.amazonaws.com
   ```

2. 给镜像打 tag（将 yourusername 替换为你的 Docker Hub 用户名）：
   ```bash
   docker tag profile-board:latest yourusername/profile-board:latest
   ```
   or
   ```bash
   docker tag profile-board:latest 160071257600.dkr.ecr.ap-southeast-2.amazonaws.com/profile-board:latest
   ```

3. 推送镜像到 Docker Hub：
   ```bash
   docker push yourusername/profile-board:latest
   ```
    or
   ```bash
   docker push 160071257600.dkr.ecr.ap-southeast-2.amazonaws.com/profile-board:latest
   ```

## Kubernetes 部署

### Deploy locally to Minikube

```bash
brew install minikube
minikube start --driver=docker
kubectl config get-contexts
kubectl get nodes
```

使用 `auto/deploy-and-test.sh` 脚本可以一键部署应用到 Kubernetes 集群：

```bash
auto/deploy-and-test.sh
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

部署完成后，根据你的 K8s 环境访问应用：

- **Minikube**: `http://<minikube-ip>:30080/heartbeat`
- **Docker Desktop**: `http://localhost:30080/heartbeat`
- **端口转发**:
  ```bash
  kubectl port-forward svc/profile-board-service 8080:8080
  # 然后访问 http://localhost:8080/heartbeat
  ```

### Deploy on AWS EKS
1. Update eks config
```bash
aws eks update-kubeconfig \
--region ap-southeast-2 \
--name attractive-country-walrus \
--profile PowerUserPlusRole-160071257600 \
--alias tw
```

2. Deploy
```bash
kubectl --context tw apply -f k8s/deployment-aws.yaml
kubectl --context tw apply -f k8s/service.yaml 
kubectl --context tw apply -f k8s/deployment-aws.yaml
```
Note that use node first and then change it to LB，or the external ip will be pending forever.

3. Get external ip
```bash
kubectl get svc
```

4. curl to test
```bash
curl --request GET \
  --url http://<externalIP>/heartbeat
```

### Deploy a pod for testing

```bash
kubectl run test-network \
  --image=alpine:3.18 \
  --restart=Never \
  --command -- sh -c '
    apk add --no-cache curl > /dev/null 2>&1
    echo "Testing ECR Public..."
    curl -s -o /dev/null -w "ECR HTTP status: %{http_code}\n" https://public.ecr.aws/v2/docker/library/curl/manifests/latest
    echo "Testing Internet..."
    curl -s -o /dev/null -w "Internet HTTP status: %{http_code}\n" https://www.google.com
  '
```

```bash
kubectl logs -f test-network
```
