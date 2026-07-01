FROM python:3.11-slim
# Versiones fijadas a propósito (esto ES la lección de reproducibilidad):
#  - scikit-learn / numpy / scipy: deben COINCIDIR con las que entrenaron el
#    modelo, o al deserializar salta InconsistentVersionWarning y las
#    predicciones pueden ser inválidas.
#  - fastapi / starlette / uvicorn: el scoring server de mlflow 2.22.5 usa
#    FastAPI y se rompe con starlette 1.x / fastapi 0.138 (AttributeError:
#    'FastAPI' object has no attribute 'route'). Se fijan al rango con el que
#    mlflow 2.22.5 fue construido (starlette < 0.47, fastapi < 0.116).
RUN pip install --no-cache-dir \
    "mlflow==2.22.5" \
    "scikit-learn==1.7.2" \
    "numpy==2.2.6" \
    "scipy==1.15.3" \
    "fastapi<0.116" \
    "starlette<0.47" \
    "uvicorn[standard]<1" \
    boto3
EXPOSE 5000
