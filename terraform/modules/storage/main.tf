# ---------------------------------------------------------------------------
# Red compartida: todos los contenedores se ven entre sí por nombre de servicio
# ---------------------------------------------------------------------------
resource "docker_network" "mlops" {
  name = "mlops-${var.environment}"
}

# ---------------------------------------------------------------------------
# Volúmenes: persistencia de metadata (postgres) y artefactos (minio)
# ---------------------------------------------------------------------------
resource "docker_volume" "postgres_data" {
  name = "mlops-pg-${var.environment}"
}

resource "docker_volume" "minio_data" {
  name = "mlops-minio-${var.environment}"
}

# ---------------------------------------------------------------------------
# PostgreSQL — backend store de MLflow
# ---------------------------------------------------------------------------
resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_container" "postgres" {
  name  = "postgres-${var.environment}"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_USER=mlflow",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=mlflow"
  ]

  networks_advanced {
    name    = docker_network.mlops.name
    aliases = ["postgres"]
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U mlflow"]
    interval = "5s"
    timeout  = "3s"
    retries  = 5
  }
}

# ---------------------------------------------------------------------------
# MinIO — artifact store S3-compatible
# ---------------------------------------------------------------------------
resource "docker_image" "minio" {
  name         = "minio/minio:latest"
  keep_locally = true
}

resource "docker_container" "minio" {
  name    = "minio-${var.environment}"
  image   = docker_image.minio.image_id
  command = ["server", "/data", "--console-address", ":9001"]

  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}"
  ]

  networks_advanced {
    name    = docker_network.mlops.name
    aliases = ["minio"]
  }

  ports {
    internal = 9000
    external = var.minio_api_port
  }
  ports {
    internal = 9001
    external = var.minio_console_port
  }

  volumes {
    volume_name    = docker_volume.minio_data.name
    container_path = "/data"
  }
}

# ---------------------------------------------------------------------------
# Init: crea el bucket de artefactos con el cliente mc (corre una vez y muere)
# ---------------------------------------------------------------------------
resource "docker_image" "mc" {
  name         = "minio/mc:latest"
  keep_locally = true
}

resource "docker_container" "create_bucket" {
  name     = "create-bucket-${var.environment}"
  image    = docker_image.mc.image_id
  must_run = false # es un job, no un servicio permanente
  restart  = "no"

  networks_advanced {
    name = docker_network.mlops.name
  }

  entrypoint = ["/bin/sh", "-c"]
  command = [
    "until mc alias set local http://minio:9000 ${var.minio_root_user} ${var.minio_root_password}; do sleep 2; done && mc mb -p local/${var.artifact_bucket} || true"
  ]

  depends_on = [docker_container.minio]
}
