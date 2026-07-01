module "storage" {
  source = "./modules/storage"

  environment         = var.environment
  minio_api_port      = var.minio_api_port
  minio_console_port  = var.minio_console_port
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
  postgres_password   = var.postgres_password
  artifact_bucket     = var.artifact_bucket
}

module "mlflow" {
  source = "./modules/mlflow"

  environment         = var.environment
  network_name        = module.storage.network_name
  mlflow_port         = var.mlflow_port
  postgres_password   = var.postgres_password
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
  artifact_bucket     = var.artifact_bucket

  depends_on = [module.storage]
}

module "serving" {
  count  = var.enable_serving ? 1 : 0
  source = "./modules/serving"

  environment         = var.environment
  network_name        = module.storage.network_name
  serving_port        = var.serving_port
  tracking_uri        = "http://mlflow:5000"
  model_name          = var.serving_model_name
  model_version       = var.serving_model_version
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password

  depends_on = [module.mlflow]
}

# ---------------------------------------------------------------------------
# TODO 4 — moved blocks: si ya tenías un stack aplicado con el main.tf plano
# (pre-refactor), estos mapeos evitan que Terraform destruya y recree todo
# solo por haber movido los recursos a módulos.
# ---------------------------------------------------------------------------
moved {
  from = docker_network.mlops
  to   = module.storage.docker_network.mlops
}

moved {
  from = docker_volume.postgres_data
  to   = module.storage.docker_volume.postgres_data
}

moved {
  from = docker_volume.minio_data
  to   = module.storage.docker_volume.minio_data
}

moved {
  from = docker_image.postgres
  to   = module.storage.docker_image.postgres
}

moved {
  from = docker_container.postgres
  to   = module.storage.docker_container.postgres
}

moved {
  from = docker_image.minio
  to   = module.storage.docker_image.minio
}

moved {
  from = docker_container.minio
  to   = module.storage.docker_container.minio
}

moved {
  from = docker_image.mc
  to   = module.storage.docker_image.mc
}

moved {
  from = docker_container.create_bucket
  to   = module.storage.docker_container.create_bucket
}

moved {
  from = docker_image.mlflow
  to   = module.mlflow.docker_image.mlflow
}

moved {
  from = docker_container.mlflow
  to   = module.mlflow.docker_container.mlflow
}
