# ---------------------------------------------------------------------------
# MLflow tracking server (imagen custom con psycopg2 + boto3)
# ---------------------------------------------------------------------------
resource "docker_image" "mlflow" {
  name = "mlflow-server:local"
  build {
    context    = "${path.module}/../../../docker"
    dockerfile = "mlflow.Dockerfile"
  }
}

resource "docker_container" "mlflow" {
  name  = "mlflow-${var.environment}"
  image = docker_image.mlflow.image_id

  env = [
    "MLFLOW_S3_ENDPOINT_URL=http://minio:9000",
    "AWS_ACCESS_KEY_ID=${var.minio_root_user}",
    "AWS_SECRET_ACCESS_KEY=${var.minio_root_password}"
  ]

  networks_advanced {
    name    = var.network_name
    aliases = ["mlflow"]
  }

  command = [
    "mlflow", "server",
    "--host", "0.0.0.0",
    "--port", "5000",
    "--backend-store-uri", "postgresql://mlflow:${var.postgres_password}@postgres:5432/mlflow",
    "--artifacts-destination", "s3://${var.artifact_bucket}/",
    "--serve-artifacts"
  ]

  ports {
    internal = 5000
    external = var.mlflow_port
  }
}
