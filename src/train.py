#!/usr/bin/env python3
"""
TensorFlow Training Script
Production-ready template for training TensorFlow models
"""

import os
import argparse
import logging
import json
from datetime import datetime
from pathlib import Path

import tensorflow as tf
import numpy as np
from tensorflow.keras import layers, models

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def create_model(input_shape=(224, 224, 3), num_classes=10):
    """
    Create a sample CNN model for image classification
    """
    model = models.Sequential([
        layers.Conv2D(32, (3, 3), activation='relu', input_shape=input_shape),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.Flatten(),
        layers.Dense(64, activation='relu'),
        layers.Dense(num_classes, activation='softmax')
    ])
    
    return model

def load_dataset():
    """
    Load sample dataset (MNIST for demonstration)
    """
    logger.info("Loading MNIST dataset...")
    (x_train, y_train), (x_test, y_test) = tf.keras.datasets.mnist.load_data()
    
    # Reshape and normalize
    x_train = x_train.reshape(-1, 28, 28, 1).astype('float32') / 255.0
    x_test = x_test.reshape(-1, 28, 28, 1).astype('float32') / 255.0
    
    # Convert labels to one-hot
    y_train = tf.keras.utils.to_categorical(y_train, 10)
    y_test = tf.keras.utils.to_categorical(y_test, 10)
    
    return (x_train, y_train), (x_test, y_test)

def train_model(args):
    """
    Main training function
    """
    logger.info("Starting model training...")
    
    # Set random seeds for reproducibility
    tf.random.set_seed(args.seed)
    np.random.seed(args.seed)
    
    # Load dataset
    (x_train, y_train), (x_test, y_test) = load_dataset()
    
    # Create model
    model = create_model(input_shape=(28, 28, 1), num_classes=10)
    
    # Compile model
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.learning_rate),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Callbacks
    callbacks = []
    
    # Model checkpoint
    checkpoint_dir = Path(args.checkpoint_dir)
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    
    checkpoint_callback = tf.keras.callbacks.ModelCheckpoint(
        filepath=str(checkpoint_dir / 'model-{epoch:02d}.h5'),
        save_best_only=True,
        monitor='val_accuracy',
        mode='max'
    )
    callbacks.append(checkpoint_callback)
    
    # TensorBoard
    if args.tensorboard:
        log_dir = Path(args.log_dir) / datetime.now().strftime("%Y%m%d-%H%M%S")
        log_dir.mkdir(parents=True, exist_ok=True)
        
        tensorboard_callback = tf.keras.callbacks.TensorBoard(
            log_dir=str(log_dir),
            histogram_freq=1
        )
        callbacks.append(tensorboard_callback)
    
    # Early stopping
    if args.early_stopping:
        early_stopping_callback = tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=args.patience,
            restore_best_weights=True
        )
        callbacks.append(early_stopping_callback)
    
    # Train model
    logger.info(f"Training for {args.epochs} epochs...")
    history = model.fit(
        x_train, y_train,
        epochs=args.epochs,
        batch_size=args.batch_size,
        validation_split=0.2,
        callbacks=callbacks,
        verbose=1
    )
    
    # Evaluate model
    logger.info("Evaluating model...")
    test_loss, test_accuracy = model.evaluate(x_test, y_test, verbose=0)
    logger.info(f"Test accuracy: {test_accuracy:.4f}, Test loss: {test_loss:.4f}")
    
    # Save final model
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save as SavedModel
    model.save(str(output_dir / 'saved_model'))
    logger.info(f"Model saved to {output_dir / 'saved_model'}")
    
    # Save as Keras model
    model.save(str(output_dir / 'model.h5'))
    logger.info(f"Model saved to {output_dir / 'model.h5'}")
    
    # Save training history
    history_path = output_dir / 'training_history.json'
    with open(history_path, 'w') as f:
        json.dump(history.history, f, indent=2)
    logger.info(f"Training history saved to {history_path}")
    
    # Save model summary
    summary_path = output_dir / 'model_summary.txt'
    with open(summary_path, 'w') as f:
        model.summary(print_fn=lambda x: f.write(x + '\n'))
    logger.info(f"Model summary saved to {summary_path}")
    
    # Save training metadata
    metadata = {
        'timestamp': datetime.now().isoformat(),
        'test_accuracy': float(test_accuracy),
        'test_loss': float(test_loss),
        'epochs': args.epochs,
        'batch_size': args.batch_size,
        'learning_rate': args.learning_rate,
        'model_architecture': 'CNN',
        'dataset': 'MNIST',
        'input_shape': [28, 28, 1],
        'num_classes': 10
    }
    
    metadata_path = output_dir / 'training_metadata.json'
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    logger.info(f"Training metadata saved to {metadata_path}")
    
    return model, history, test_accuracy

def main():
    parser = argparse.ArgumentParser(description='Train TensorFlow model')
    
    # Training parameters
    parser.add_argument('--epochs', type=int, default=10,
                       help='Number of training epochs')
    parser.add_argument('--batch-size', type=int, default=32,
                       help='Batch size for training')
    parser.add_argument('--learning-rate', type=float, default=0.001,
                       help='Learning rate')
    parser.add_argument('--seed', type=int, default=42,
                       help='Random seed for reproducibility')
    
    # Output directories
    parser.add_argument('--output-dir', type=str, default='./output',
                       help='Directory to save trained model')
    parser.add_argument('--checkpoint-dir', type=str, default='./checkpoints',
                       help='Directory to save model checkpoints')
    parser.add_argument('--log-dir', type=str, default='./logs',
                       help='Directory for TensorBoard logs')
    
    # Callback options
    parser.add_argument('--tensorboard', action='store_true',
                       help='Enable TensorBoard logging')
    parser.add_argument('--early-stopping', action='store_true',
                       help='Enable early stopping')
    parser.add_argument('--patience', type=int, default=5,
                       help='Patience for early stopping')
    
    args = parser.parse_args()
    
    # Create output directories
    for dir_path in [args.output_dir, args.checkpoint_dir, args.log_dir]:
        Path(dir_path).mkdir(parents=True, exist_ok=True)
    
    # Train model
    try:
        model, history, accuracy = train_model(args)
        logger.info(f"Training completed successfully with accuracy: {accuracy:.4f}")
    except Exception as e:
        logger.error(f"Training failed: {e}")
        raise

if __name__ == "__main__":
    main()