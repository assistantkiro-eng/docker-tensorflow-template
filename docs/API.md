# TensorFlow Serving API Documentation

## 📋 Overview

This document describes the REST API endpoints provided by the TensorFlow serving template. The API follows RESTful principles and returns JSON responses.

## 🚀 Base URL

```
http://localhost:8501
```

**Production:** `https://your-domain.com`

## 🔐 Authentication

Currently, the API does not require authentication for demonstration purposes. For production use, implement one of:

1. **API Key Authentication:** Add `X-API-Key` header
2. **JWT Tokens:** Use Bearer token authentication
3. **OAuth2:** For enterprise deployments

## 📊 Health & Status Endpoints

### **GET /** - Service Status
Returns basic service information.

**Request:**
```bash
curl http://localhost:8501/
```

**Response:**
```json
{
  "service": "TensorFlow Model Serving",
  "version": "1.0.0",
  "status": "healthy",
  "model_loaded": true
}
```

### **GET /health** - Health Check
Check if the service and model are healthy.

**Request:**
```bash
curl http://localhost:8501/health
```

**Response:**
```json
{
  "status": "healthy",
  "model": "loaded",
  "timestamp": 1640995200.123456
}
```

**Status Codes:**
- `200 OK`: Service and model are healthy
- `503 Service Unavailable`: Model not loaded or service unhealthy

### **GET /metrics** - Prometheus Metrics
Export Prometheus metrics for monitoring.

**Request:**
```bash
curl http://localhost:8501/metrics
```

**Response:**
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total 42

# HELP http_request_duration_seconds HTTP request latency
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.05"} 12
http_request_duration_seconds_bucket{le="0.1"} 34
http_request_duration_seconds_bucket{le="0.25"} 42
http_request_duration_seconds_bucket{le="0.5"} 42
http_request_duration_seconds_bucket{le="1"} 42
http_request_duration_seconds_bucket{le="2.5"} 42
http_request_duration_seconds_bucket{le="5"} 42
http_request_duration_seconds_bucket{le="+Inf"} 42
http_request_duration_seconds_sum 1.234
http_request_duration_seconds_count 42
```

## 🤖 Model Endpoints

### **POST /predict** - Make Predictions
Make predictions using the loaded TensorFlow model.

**Request:**
```bash
curl -X POST http://localhost:8501/predict \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [[1.0, 2.0, 3.0, 4.0, 5.0]]
  }'
```

**Request Body:**
```json
{
  "inputs": [
    [1.0, 2.0, 3.0, 4.0, 5.0],
    [6.0, 7.0, 8.0, 9.0, 10.0]
  ]
}
```

**Parameters:**
- `inputs` (required): Array of input data. Shape depends on the model.

**Response:**
```json
{
  "success": true,
  "predictions": [
    [0.1, 0.2, 0.3, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.1, 0.2, 0.3, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0]
  ],
  "model": "tensorflow-model"
}
```

**Status Codes:**
- `200 OK`: Prediction successful
- `400 Bad Request`: Invalid input data
- `500 Internal Server Error`: Prediction failed
- `503 Service Unavailable`: Model not loaded

### **GET /model/info** - Model Information
Get information about the loaded model.

**Request:**
```bash
curl http://localhost:8501/model/info
```

**Response:**
```json
{
  "model_type": "Sequential",
  "loaded": true,
  "path": "/models/tensorflow-model",
  "summary": "Model: \"sequential\"\n_________________________________________________________________\n Layer (type)                Output Shape              Param #   \n=================================================================\n dense (Dense)               (None, 10)                60        \n=================================================================\nTotal params: 60 (240.00 Byte)\nTrainable params: 60 (240.00 Byte)\nNon-trainable params: 0 (0.00 Byte)\n_________________________________________________________________\n"
}
```

## 🎯 Example Usage

### **Python Client**
```python
import requests
import json

class TensorFlowClient:
    def __init__(self, base_url="http://localhost:8501"):
        self.base_url = base_url
    
    def health_check(self):
        """Check service health"""
        response = requests.get(f"{self.base_url}/health")
        return response.json()
    
    def predict(self, inputs):
        """Make predictions"""
        data = {"inputs": inputs}
        response = requests.post(
            f"{self.base_url}/predict",
            json=data,
            headers={"Content-Type": "application/json"}
        )
        return response.json()
    
    def get_model_info(self):
        """Get model information"""
        response = requests.get(f"{self.base_url}/model/info")
        return response.json()

# Usage
client = TensorFlowClient()

# Check health
health = client.health_check()
print(f"Service status: {health['status']}")

# Make prediction
inputs = [[1.0, 2.0, 3.0, 4.0, 5.0]]
result = client.predict(inputs)
print(f"Predictions: {result['predictions']}")
```

### **JavaScript/Node.js Client**
```javascript
const axios = require('axios');

class TensorFlowClient {
  constructor(baseUrl = 'http://localhost:8501') {
    this.client = axios.create({ baseURL: baseUrl });
  }

  async healthCheck() {
    const response = await this.client.get('/health');
    return response.data;
  }

  async predict(inputs) {
    const response = await this.client.post('/predict', {
      inputs
    });
    return response.data;
  }

  async getModelInfo() {
    const response = await this.client.get('/model/info');
    return response.data;
  }
}

// Usage
const client = new TensorFlowClient();

async function main() {
  try {
    const health = await client.healthCheck();
    console.log('Service status:', health.status);

    const inputs = [[1.0, 2.0, 3.0, 4.0, 5.0]];
    const result = await client.predict(inputs);
    console.log('Predictions:', result.predictions);
  } catch (error) {
    console.error('Error:', error.message);
  }
}

main();
```

### **cURL Examples**
```bash
# Health check
curl http://localhost:8501/health

# Model information
curl http://localhost:8501/model/info

# Batch prediction
curl -X POST http://localhost:8501/predict \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [
      [1.0, 2.0, 3.0, 4.0, 5.0],
      [6.0, 7.0, 8.0, 9.0, 10.0],
      [11.0, 12.0, 13.0, 14.0, 15.0]
    ]
  }'

# Get Prometheus metrics
curl http://localhost:8501/metrics
```

## 🔧 Advanced Usage

### **Batch Processing**
The API supports batch processing for improved performance:

```python
import numpy as np

# Generate batch of 1000 samples
batch_size = 1000
input_dim = 5
inputs = np.random.randn(batch_size, input_dim).tolist()

# Send batch request
response = requests.post(
    "http://localhost:8501/predict",
    json={"inputs": inputs}
)
```

### **Error Handling**
```python
import requests
from requests.exceptions import RequestException

def safe_predict(inputs):
    try:
        response = requests.post(
            "http://localhost:8501/predict",
            json={"inputs": inputs},
            timeout=30  # 30 second timeout
        )
        response.raise_for_status()
        return response.json()
    except RequestException as e:
        if e.response is not None:
            # Server returned an error
            if e.response.status_code == 400:
                print("Bad request:", e.response.json())
            elif e.response.status_code == 503:
                print("Service unavailable:", e.response.json())
            else:
                print(f"HTTP error {e.response.status_code}:", e.response.json())
        else:
            # Network or connection error
            print("Network error:", str(e))
        return None
```

### **Monitoring Integration**
```python
import time
from prometheus_client import Counter, Histogram

# Define metrics
PREDICTION_COUNT = Counter('predictions_total', 'Total predictions made')
PREDICTION_LATENCY = Histogram('prediction_latency_seconds', 'Prediction latency')

def monitored_predict(inputs):
    start_time = time.time()
    
    try:
        result = predict(inputs)
        PREDICTION_COUNT.inc()
        
        latency = time.time() - start_time
        PREDICTION_LATENCY.observe(latency)
        
        return result
    except Exception as e:
        # Increment error counter
        PREDICTION_ERRORS.inc()
        raise e
```

## 🛡️ Security Considerations

### **Production Deployment**
1. **Enable HTTPS:** Use TLS/SSL encryption
2. **Add Authentication:** Implement API key or token-based auth
3. **Rate Limiting:** Prevent abuse with rate limits
4. **Input Validation:** Validate all input data
5. **CORS Configuration:** Restrict cross-origin requests

### **Environment Variables for Security**
```bash
# Enable authentication
export API_AUTH_ENABLED=true
export API_KEY=your-secret-key

# Enable HTTPS
export SSL_CERT_PATH=/path/to/cert.pem
export SSL_KEY_PATH=/path/to/key.pem

# Rate limiting
export RATE_LIMIT_REQUESTS=100
export RATE_LIMIT_PERIOD=60  # seconds
```

## 📈 Performance Tips

1. **Use Batch Predictions:** Send multiple inputs in one request
2. **Enable Compression:** Use gzip compression for large responses
3. **Connection Pooling:** Reuse HTTP connections
4. **Async Processing:** For high-throughput applications
5. **Caching:** Cache frequent predictions

### **Performance Benchmark**
```bash
# Test with Apache Bench
ab -n 1000 -c 10 -p test_data.json -T application/json http://localhost:8501/predict

# Test with wrk
wrk -t4 -c100 -d30s -s test_data.lua http://localhost:8501/predict
```

## 🔍 Troubleshooting

### **Common Issues**

#### **Model Not Loading**
```bash
# Check model path
docker exec -it tensorflow-container ls -la /models/

# Check logs
docker logs tensorflow-container

# Test model loading manually
docker exec -it tensorflow-container python3 -c "
import tensorflow as tf
model = tf.saved_model.load('/models/tensorflow-model')
print('Model loaded successfully')
"
```

#### **High Latency**
```bash
# Check resource usage
docker stats tensorflow-container

# Check network latency
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8501/health

# Enable performance logging
export TF_CPP_MIN_LOG_LEVEL=0  # Enable all logs
```

#### **Memory Issues**
```bash
# Check memory usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Increase memory limits
docker run -d -p 8501:8501 --memory="4g" tensorflow-serving:latest
```

## 📚 Additional Resources

- [TensorFlow Serving REST API](https://www.tensorflow.org/tfx/serving/api_rest)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Prometheus Client Python](https://github.com/prometheus/client_python)
- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

## 📄 License

This API is part of the TensorFlow Serving Template, released under the MIT License.

## 🙏 Support

For issues and questions:
- [GitHub Issues](https://github.com/aioperations-io/docker-tensorflow-template/issues)
- [Discord Community](https://discord.gg/aiops-templates)
- [Email Support](support@aioperations.io)