#!/usr/bin/env python3
"""
TensorFlow Model Serving Script
Production-ready template for serving TensorFlow models
"""

import os
import logging
import signal
import sys
from typing import Optional

import tensorflow as tf
import numpy as np
from fastapi import FastAPI, HTTPException
import uvicorn
from prometheus_client import Counter, Histogram, generate_latest

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests')
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency')

# FastAPI app
app = FastAPI(
    title="TensorFlow Model Serving API",
    description="Production-ready TensorFlow model serving template",
    version="1.0.0"
)

# Global model variable
model: Optional[tf.keras.Model] = None

def load_model(model_path: str = None) -> tf.keras.Model:
    """
    Load TensorFlow model from path
    """
    if model_path is None:
        model_path = os.getenv('MODEL_PATH', '/models/tensorflow-model')
    
    logger.info(f"Loading model from: {model_path}")
    
    try:
        # Try to load as SavedModel
        model = tf.saved_model.load(model_path)
        logger.info("Model loaded successfully as SavedModel")
        return model
    except Exception as e:
        logger.warning(f"Failed to load as SavedModel: {e}")
    
    try:
        # Try to load as Keras model
        model = tf.keras.models.load_model(model_path)
        logger.info("Model loaded successfully as Keras model")
        return model
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise RuntimeError(f"Could not load model from {model_path}")

@app.on_event("startup")
async def startup_event():
    """Initialize model on startup"""
    global model
    try:
        model = load_model()
        logger.info("Model initialized successfully")
        
        # Warm up the model
        if hasattr(model, 'predict'):
            dummy_input = np.random.randn(1, 224, 224, 3).astype(np.float32)
            _ = model.predict(dummy_input)
            logger.info("Model warmed up successfully")
    except Exception as e:
        logger.error(f"Failed to initialize model: {e}")
        sys.exit(1)

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "TensorFlow Model Serving",
        "version": "1.0.0",
        "status": "healthy",
        "model_loaded": model is not None
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    return {
        "status": "healthy",
        "model": "loaded",
        "timestamp": tf.timestamp().numpy()
    }

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.post("/predict")
@REQUEST_LATENCY.time()
async def predict(data: dict):
    """
    Make predictions using the loaded model
    """
    REQUEST_COUNT.inc()
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Extract input data
        input_data = data.get("inputs")
        if input_data is None:
            raise HTTPException(status_code=400, detail="No input data provided")
        
        # Convert to tensor
        if isinstance(input_data, list):
            input_tensor = tf.convert_to_tensor(input_data)
        else:
            input_tensor = tf.convert_to_tensor([input_data])
        
        # Make prediction
        if hasattr(model, 'predict'):
            predictions = model.predict(input_tensor)
        elif hasattr(model, '__call__'):
            predictions = model(input_tensor)
        else:
            raise HTTPException(status_code=500, detail="Model doesn't support prediction")
        
        # Convert to Python types
        if hasattr(predictions, 'numpy'):
            predictions = predictions.numpy().tolist()
        
        return {
            "success": True,
            "predictions": predictions,
            "model": os.getenv('MODEL_NAME', 'tensorflow-model')
        }
        
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/model/info")
async def model_info():
    """Get model information"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    info = {
        "model_type": type(model).__name__,
        "loaded": True,
        "path": os.getenv('MODEL_PATH', 'unknown')
    }
    
    # Add model-specific info
    if hasattr(model, 'summary'):
        try:
            # Try to get model summary
            import io
            string_buffer = io.StringIO()
            model.summary(print_fn=lambda x: string_buffer.write(x + '\n'))
            info["summary"] = string_buffer.getvalue()
        except:
            pass
    
    return info

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down gracefully...")
    sys.exit(0)

if __name__ == "__main__":
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start server
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', 8501))
    
    logger.info(f"Starting TensorFlow serving on {host}:{port}")
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info",
        access_log=True
    )