"""Entrenamiento trivial que loguea a MLflow.

El foco de este práctico es la infraestructura, NO el modelo.
Un LogisticRegression sobre iris basta para probar que el stack funciona:
los parámetros y métricas van a Postgres, el modelo serializado va a MinIO.
"""
import mlflow
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# En Codespaces (Plan A) usa el puerto reenviado; en local (Plan B) es localhost.
mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("practico-iac")

X, y = load_iris(return_X_y=True)
X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.2, random_state=42)

for c in [0.1, 1.0, 10.0]:
    with mlflow.start_run():
        model = LogisticRegression(C=c, max_iter=200)
        model.fit(X_tr, y_tr)
        acc = accuracy_score(y_te, model.predict(X_te))

        mlflow.log_param("C", c)
        mlflow.log_metric("accuracy", acc)
        mlflow.sklearn.log_model(model, "model")  # el artefacto aterriza en MinIO
        print(f"C={c}  accuracy={acc:.3f}")

print("\nListo. Revisa los runs en la UI de MLflow y el bucket en la consola de MinIO.")
