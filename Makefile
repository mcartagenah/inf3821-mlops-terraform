# Atajos para el práctico. Ejecuta `make help` para ver todo.
# Detrás de cada atajo hay un comando de Terraform "crudo" — míralo aquí para aprenderlo.

TF = terraform -chdir=terraform

.PHONY: help init workspace-dev workspace-prod workspace-prod-create up prod-up serve-dev serve-prod train smoke output plan down prod-down clean fmt

help:  ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

init:  ## Inicializa Terraform (descarga el provider docker)
	$(TF) init

workspace-dev:
	$(TF) workspace select default

workspace-prod:
	$(TF) workspace select prod

workspace-prod-create:
	$(TF) workspace select prod || $(TF) workspace new prod

plan: workspace-dev  ## Muestra el plan para el ambiente dev
	$(TF) plan -var-file=dev.tfvars

up: workspace-dev  ## Levanta el stack dev (MLflow + Postgres + MinIO)
	$(TF) apply -var-file=dev.tfvars

prod-up: workspace-prod-create  ## Levanta un segundo stack aislado (TODO 3: ambientes)
	$(TF) apply -var-file=prod.tfvars

serve-dev: workspace-dev  ## Levanta el modelo servido en dev (TODO 5, puerto 5002)
	$(TF) apply -var-file=dev.tfvars -var="enable_serving=true"

serve-prod: workspace-prod-create  ## Levanta el modelo servido en prod (TODO 5, puerto 5012)
	$(TF) apply -var-file=prod.tfvars -var="enable_serving=true"

output: workspace-dev  ## Muestra las URLs de MLflow y MinIO
	$(TF) output

train:  ## Corre el entrenamiento de prueba y loguea a MLflow
	python3 ml/train.py

smoke:  ## Espera a MLflow y corre el entrenamiento (verificación end-to-end)
	bash scripts/smoke_test.sh

fmt:  ## Formatea los archivos .tf
	$(TF) fmt

down: workspace-dev  ## Destruye el stack dev
	$(TF) destroy -var-file=dev.tfvars

prod-down: workspace-prod  ## Destruye el stack prod
	$(TF) destroy -var-file=prod.tfvars

clean: down  ## Destruye todo (dev y prod)
	-$(MAKE) prod-down
