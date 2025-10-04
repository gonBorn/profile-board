#!/bin/bash

echo "=== Profile Board K8s Deployment Script ==="

# 检查 kubectl 连接
echo "1. Checking kubectl connection..."
kubectl cluster-info

# 应用 Deployment
echo "2. Applying Deployment..."
kubectl apply -f ../k8s/development.yaml

# 应用 Service
echo "3. Applying Service..."
kubectl apply -f ../k8s/service.yaml

# 等待 Pod 启动
echo "4. Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=profile-board --timeout=120s

# 检查部署状态
echo "5. Checking deployment status..."
kubectl get pods -l app=profile-board
kubectl get svc profile-board-service

# 获取访问信息
echo "6. Getting access information..."
NODE_PORT=$(kubectl get svc profile-board-service -o jsonpath='{.spec.ports[0].nodePort}')
echo "Service is exposed on NodePort: $NODE_PORT"

# 检测 Kubernetes 环境类型
if kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | grep -q "192.168"; then
    echo "Detected: Minikube or similar local cluster"
    echo "Try accessing: http://$(minikube ip 2>/dev/null || echo "localhost"):$NODE_PORT/heartbeat"
elif kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | grep -q "127.0.0.1"; then
    echo "Detected: Docker Desktop Kubernetes"
    echo "Try accessing: http://localhost:$NODE_PORT/heartbeat"
else
    echo "Try accessing: http://localhost:$NODE_PORT/heartbeat"
fi

# 提供端口转发选项
echo "7. Alternative: Use port-forward for direct access"
echo "Run: kubectl port-forward svc/profile-board-service 8080:8080"
echo "Then access: http://localhost:8080/heartbeat"

# 测试连接
echo "8. Testing connection (if available)..."
sleep 5
if command -v curl >/dev/null 2>&1; then
    echo "Testing NodePort access..."
    curl -s -o /dev/null -w "%{http_code}" http://localhost:$NODE_PORT/heartbeat || echo "NodePort test failed"

    echo "Starting port-forward test..."
    kubectl port-forward svc/profile-board-service 8081:8080 &
    PF_PID=$!
    sleep 3
    curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/heartbeat || echo "Port-forward test failed"
    kill $PF_PID 2>/dev/null
else
    echo "curl not available, please test manually"
fi

echo "=== Deployment Complete ==="
