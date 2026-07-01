#!/usr/bin/env bash
set -e
echo "Esperando a que MLflow responda..."
until curl -sf http://localhost:5000/health > /dev/null; do sleep 2; done
echo "MLflow OK. Corriendo entrenamiento de prueba..."
python ml/train.py
echo "Smoke test completo."
