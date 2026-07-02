# ---------------------------------------------------------------------------
# Model serving — expone el último modelo registrado como API REST
# (TODO 5: composición de un servicio nuevo sobre el stack existente)
# ---------------------------------------------------------------------------
resource "docker_image" "serving" {
  name = "mlflow-serving:${var.environment}"
  build {
    context    = "${path.module}/../../../docker"
    dockerfile = "serving.Dockerfile"
  }
}

resource "docker_container" "serving" {
  name  = "serving-${var.environment}"
  image = docker_image.serving.image_id

  env = [
    "MLFLOW_TRACKING_URI=${var.tracking_uri}",
    "MLFLOW_S3_ENDPOINT_URL=http://minio:9000",
    "AWS_ACCESS_KEY_ID=${var.minio_root_user}",
    "AWS_SECRET_ACCESS_KEY=${var.minio_root_password}"
  ]

  networks_advanced {
    name    = var.network_name
    aliases = ["serving"]
  }

  command = [
    "mlflow", "models", "serve",
    "-m", "models:/${var.model_name}/${var.model_version}",
    "--host", "0.0.0.0",
    "--port", "5000",
    "--env-manager", "local"
  ]

  ports {
    internal = 5000
    external = var.serving_port
  }
}
