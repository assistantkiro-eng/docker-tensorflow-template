# TensorFlow Serving Deployment Guide

## 📋 Overview

This guide covers deployment of the TensorFlow serving template in various environments, from local development to production Kubernetes clusters.

## 🚀 Quick Start

### **Local Development**
```bash
# Clone the template
git clone https://github.com/aioperations-io/docker-tensorflow-template.git
cd docker-tensorflow-template

# Build and run
./scripts/build.sh --type cpu
./scripts/deploy.sh --env development
```

### **Verify Deployment**
```bash
# Check service health
curl http://localhost:8501/health

# Test prediction
curl -X POST http://localhost:8501/predict \
  -H "Content-Type: application/json" \
  -d '{"inputs": [[1.0, 2.0, 3.0, 4.0, 5.0]]}'
```

## 🏗️ Deployment Architectures

### **1. Single Container (Development)**
```
┌─────────────────────────────────┐
│   TensorFlow Serving Container  │
│   - REST API: 8501              │
│   - gRPC: 8500                  │
│   - Model: /models/             │
└─────────────────────────────────┘
```

### **2. Multi-Service (Staging)**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   TensorFlow│    │  Prometheus │    │   Grafana   │
│   Serving   │◄──►│   Metrics   │◄──►│  Dashboard  │
└─────────────┘    └─────────────┘    └─────────────┘
```

### **3. Production Cluster**
```
┌─────────────────────────────────────────────────┐
│                Kubernetes Cluster               │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │   Pod   │  │   Pod   │  │   Pod   │        │
│  │ (TF 1)  │  │ (TF 2)  │  │ (TF 3)  │        │
│  └─────────┘  └─────────┘  └─────────┘        │
│        │            │            │             │
│  ┌─────────────────────────────────────┐      │
│  │           Load Balancer             │      │
│  └─────────────────────────────────────┘      │
│                       │                       │
│                 ┌───────────┐                 │
│                 │ Ingress   │                 │
│                 │ Controller │                 │
│                 └───────────┘                 │
└─────────────────────────────────────────────────┘
```

## 🔧 Environment Configurations

### **Development (.env.development)**
```bash
# Development environment
DEPLOY_ENV=development
COMPOSE_PROJECT_NAME=tensorflow-dev

# Model configuration
MODEL_NAME=tensorflow-model
MODEL_PATH=/models/tensorflow-model

# Service ports
TF_SERVING_PORT=8501
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000

# Logging
LOG_LEVEL=DEBUG
TF_CPP_MIN_LOG_LEVEL=0

# Resource limits (development)
TF_MEMORY_LIMIT=2g
TF_CPU_LIMIT=2
```

### **Staging (.env.staging)**
```bash
# Staging environment
DEPLOY_ENV=staging
COMPOSE_PROJECT_NAME=tensorflow-staging

# Model configuration
MODEL_NAME=production-model
MODEL_PATH=/models/production

# Security
API_AUTH_ENABLED=true
API_KEY=staging-secret-key

# Monitoring
METRICS_ENABLED=true
ALERTING_ENABLED=true

# Resource limits (staging)
TF_MEMORY_LIMIT=4g
TF_CPU_LIMIT=4
```

### **Production (.env.production)**
```bash
# Production environment
DEPLOY_ENV=production
COMPOSE_PROJECT_NAME=tensorflow-production

# Model configuration
MODEL_NAME=production-model-v2
MODEL_PATH=/models/production/v2

# Security
API_AUTH_ENABLED=true
API_KEY=$(cat /run/secrets/api-key)
SSL_ENABLED=true
SSL_CERT=/etc/ssl/certs/tls.crt
SSL_KEY=/etc/ssl/private/tls.key

# High availability
REPLICAS=3
HEALTH_CHECK_INTERVAL=10s

# Resource limits (production)
TF_MEMORY_LIMIT=8g
TF_CPU_LIMIT=8
TF_GPU_COUNT=1  # If using GPU
```

## 🐳 Docker Deployment

### **Single Container**
```bash
# Build image
docker build -t tensorflow-serving:latest -f Dockerfile.cpu .

# Run container
docker run -d \
  --name tensorflow-serving \
  -p 8501:8501 \
  -p 8500:8500 \
  -v $(pwd)/models:/models \
  -e MODEL_PATH=/models/tensorflow-model \
  tensorflow-serving:latest
```

### **Docker Compose**
```bash
# Start all services
docker-compose up -d

# Start with GPU support
docker-compose --profile gpu up -d

# Start with monitoring
docker-compose --profile monitoring up -d

# Scale services
docker-compose up -d --scale tensorflow-serving-cpu=3
```

### **Docker Swarm**
```bash
# Initialize swarm (if not already)
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml tensorflow-stack

# Scale services
docker service scale tensorflow-stack_tensorflow-serving-cpu=5

# Update stack
docker stack deploy -c docker-compose.yml tensorflow-stack
```

## ☸️ Kubernetes Deployment

### **Namespace Setup**
```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tensorflow-serving
  labels:
    name: tensorflow-serving
```

### **ConfigMap for Configuration**
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tensorflow-config
  namespace: tensorflow-serving
data:
  model-name: "tensorflow-model"
  model-path: "/models/tensorflow-model"
  tf-log-level: "3"
```

### **Deployment**
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tensorflow-serving
  namespace: tensorflow-serving
  labels:
    app: tensorflow-serving
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tensorflow-serving
  template:
    metadata:
      labels:
        app: tensorflow-serving
    spec:
      containers:
      - name: tensorflow
        image: tensorflow-serving:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8501
          name: rest-api
        - containerPort: 8500
          name: grpc
        env:
        - name: MODEL_NAME
          valueFrom:
            configMapKeyRef:
              name: tensorflow-config
              key: model-name
        - name: MODEL_PATH
          valueFrom:
            configMapKeyRef:
              name: tensorflow-config
              key: model-path
        - name: TF_CPP_MIN_LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: tensorflow-config
              key: tf-log-level
        resources:
          limits:
            memory: "4Gi"
            cpu: "2"
          requests:
            memory: "2Gi"
            cpu: "1"
        livenessProbe:
          httpGet:
            path: /health
            port: 8501
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8501
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: model-storage
          mountPath: /models
      volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: tensorflow-model-pvc
```

### **Service**
```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tensorflow-service
  namespace: tensorflow-serving
spec:
  selector:
    app: tensorflow-serving
  ports:
  - name: rest-api
    port: 8501
    targetPort: 8501
  - name: grpc
    port: 8500
    targetPort: 8500
  type: LoadBalancer
```

### **Ingress**
```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tensorflow-ingress
  namespace: tensorflow-serving
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - tensorflow.example.com
    secretName: tensorflow-tls
  rules:
  - host: tensorflow.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tensorflow-service
            port:
              number: 8501
```

### **Horizontal Pod Autoscaler**
```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: tensorflow-hpa
  namespace: tensorflow-serving
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tensorflow-serving
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## ☁️ Cloud Platform Deployment

### **AWS ECS**
```json
{
  "family": "tensorflow-serving",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "tensorflow",
      "image": "tensorflow-serving:latest",
      "portMappings": [
        {
          "containerPort": 8501,
          "hostPort": 8501,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "MODEL_NAME",
          "value": "tensorflow-model"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/tensorflow-serving",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "4096"
}
```

### **Google Cloud Run**
```yaml
# cloudrun.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: tensorflow-serving
  namespace: default
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containers:
      - image: gcr.io/PROJECT_ID/tensorflow-serving:latest
        ports:
        - containerPort: 8501
        env:
        - name: MODEL_NAME
          value: "tensorflow-model"
        resources:
          limits:
            cpu: 2000m
            memory: 4Gi
          requests:
            cpu: 1000m
            memory: 2Gi
```

### **Azure Container Instances**
```bash
# Deploy to ACI
az container create \
  --resource-group myResourceGroup \
  --name tensorflow-serving \
  --image tensorflow-serving:latest \
  --ports 8501 8500 \
  --environment-variables MODEL_NAME=tensorflow-model \
  --memory 4 \
  --cpu 2 \
  --ip-address Public
```

## 🔒 Security Configuration

### **Network Security**
```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tensorflow-network-policy
  namespace: tensorflow-serving
spec:
  podSelector:
    matchLabels:
      app: tensorflow-serving
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8501
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

### **Secret Management**
```bash
# Create Kubernetes secret
kubectl create secret generic tensorflow-secrets \
  --namespace tensorflow-serving \
  --from-literal=api-key='your-api-key' \
  --from-file=tls.crt=./certs/cert.pem \
  --from-file=tls.key=./certs/key.pem

# Use in deployment
env:
- name: API_KEY
  valueFrom:
    secretKeyRef:
      name: tensorflow-secrets
      key: api-key
```

### **Pod Security**
```yaml
# pod-security.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: tensorflow-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'secret'
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      - min: 1000
        max: 2000
```

## 📊 Monitoring & Observability

### **Prometheus Configuration**
```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'tensorflow-serving'
      static_configs:
      - targets: ['tensorflow-service.tensorflow-serving.svc.cluster.local:8501']
```

### **Grafana Dashboard**
```json
{
  "dashboard": {
    "title": "TensorFlow Serving Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [{
          "expr": "rate(http_requests_total[5m])",
          "legendFormat": "{{instance}}"
        }]
      },
      {
        "title": "Prediction Latency",
        "targets": [{
          "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
          "legendFormat": "p95 latency"
        }]
      }
    ]
  }
}
```

### **Alert Rules**
```yaml
# alerts.yaml
groups:
- name: tensorflow-alerts
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status!~"2.."}[5m]) > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High error rate on TensorFlow serving"
      
  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "High prediction latency detected"
```

## 🔄 CI/CD Pipeline

### **GitHub Actions**
```yaml
# .github/workflows/deploy.yml
name: Deploy TensorFlow Serving

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Build Docker image
      run: |
        docker build -t tensorflow-serving:latest -f Dockerfile.cpu .
        
    - name: Run tests
      run: |
        ./scripts/test.sh --type all
        
    - name: Push to registry
      run: |
        docker tag tensorflow-serving:latest ghcr.io/${{ github.repository }}/tensorflow-serving:latest
        echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
        docker push ghcr.io/${{ github.repository }}/tensorflow-serving:latest
        
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
    - name: Deploy to Kubernetes
      run: |
        kubectl set image deployment/tensorflow-serving tensorflow=ghcr.io/${{ github.repository }}/tensorflow-serving:latest
        kubectl rollout status deployment/tensorflow-serving
```

### **GitLab CI**
```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - docker build -t tensorflow-serving:latest -f