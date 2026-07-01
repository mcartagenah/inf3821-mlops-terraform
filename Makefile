# Atajos para el práctico. Ejecuta `make help` para ver todo.
# Detrás de cada atajo hay un comando de Terraform "crudo" — míralo aquí para aprenderlo.

TF = terraform -chdir=terraform

.PHONY: help init up prod-up train smoke output plan down prod-down clean fmt

help:  ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

init:  ## Inicializa Terraform (descarga el provider docker)
	$(TF) init

plan:  ## Muestra el plan para el ambiente dev
	$(TF) plan -var-file=dev.tfvars

up:  ## Levanta el stack dev (MLflow + Postgres + MinIO)
	$(TF) apply -var-file=dev.tfvars

prod-up:  ## Levanta un segundo stack aislado (TODO 3: ambientes)
	$(TF) apply -var-file=prod.tfvars

output:  ## Muestra las URLs de MLflow y MinIO
	$(TF) output

train:  ## Corre el entrenamiento de prueba y loguea a MLflow
	python3 ml/train.py

smoke:  ## Espera a MLflow y corre el entrenamiento (verificación end-to-end)
	bash scripts/smoke_test.sh

fmt:  ## Formatea los archivos .tf
	$(TF) fmt

down:  ## Destruye el stack dev
	$(TF) destroy -var-file=dev.tfvars

prod-down:  ## Destruye el stack prod
	$(TF) destroy -var-file=prod.tfvars

clean: down  ## Destruye todo (dev y prod)
	-$(TF) destroy -var-file=prod.tfvars
