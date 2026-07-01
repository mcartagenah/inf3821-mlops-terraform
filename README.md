# Práctico MLOps — Infra-as-Code con Terraform + Docker

En este práctico vas a levantar un stack completo de **MLflow** (tracking server + backend Postgres + artifact store MinIO) **usando Terraform**, sin tocar la consola de Docker a mano. Vas a escribir y correr IaC de verdad: `plan`, `apply`, `destroy`.

El modelo de ML es intencionalmente trivial (un `LogisticRegression` sobre iris). **El foco es la infraestructura, no el modelo.**

---

## Arquitectura

```
        ┌─────────────┐        ┌──────────────┐
        │   MLflow    │───────▶│  PostgreSQL  │   metadata (params, métricas, runs)
        │  :5000 UI   │        └──────────────┘
        │             │        ┌──────────────┐
        │             │───────▶│    MinIO     │   artefactos (modelos serializados)
        └─────────────┘        │ :9000 / :9001│
                               └──────────────┘
        Todo declarado en Terraform. Todo corre en contenedores Docker.
```

---

## Cómo correrlo

Hay dos caminos. Usa **A** salvo que no puedas.

### Plan A — GitHub Codespaces (recomendado)

1. En este repo: botón verde **Code → Codespaces → Create codespace on main**.
2. Espera a que el devcontainer termine de construirse (trae Docker y Terraform listos).
3. En la pestaña **PORTS** verás los puertos 5000, 9000 y 9001 una vez que levantes el stack.

> ⚠️ En Codespaces la UI de MLflow **NO** está en `localhost:5000`, sino en la URL que GitHub genera para el puerto 5000 (pestaña PORTS → ícono del globo). El `train.py` sí usa `localhost:5000` porque corre *dentro* del Codespace.

### Plan B — Docker Desktop local

Requisitos: **Docker Desktop** corriendo + **Terraform ≥ 1.6** instalado.

```bash
git clone <URL-de-este-repo>
cd mlops-iac-practico
pip install -r ml/requirements.txt
```

---

## Levantar el stack

Hay dos formas equivalentes. Los **atajos con `make`** son más cómodos; los
**comandos crudos** te muestran qué hay detrás (apréndelos, son la gracia del práctico).

Con `make` (desde la raíz del repo):

```bash
make init    # descarga el provider docker
make up      # levanta el stack dev
make output  # muestra las URLs
```

Comando crudo equivalente:

```bash
cd terraform
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
terraform output
```

`make output` (o `terraform output`) te da las URLs. Abre la UI de MLflow y la consola de
MinIO (usuario/password por defecto: `minioadmin` / `minioadmin`).

> Corre `make help` para ver todos los atajos disponibles.

## Loguear experimentos

```bash
make train        # atajo
# o bien:
python ml/train.py
```

Deberías ver 3 runs aparecer en el experimento `practico-iac` en MLflow, y una carpeta
por run dentro del bucket `mlflow-artifacts` en la consola de MinIO.

---

## TODOs

Resuélvelos en orden. Cada uno dice qué deberías observar si lo lograste.

### TODO 1 — Loop de reproducibilidad *(imprescindible)*

```bash
cd terraform
terraform destroy -var-file=dev.tfvars   # todo desaparece
terraform apply   -var-file=dev.tfvars   # vuelve idéntico
```

**Observa:** el stack se reconstruye completo desde el código. Esto es el corazón de IaC.
*Pregunta:* después del destroy + apply, ¿siguen ahí tus runs anteriores? ¿Por qué sí o por qué no?
(Pista: mira qué volúmenes borra el `destroy` y cuáles no.)

### TODO 2 — Drift: estado real vs. estado deseado

Rompe el stack a mano y deja que Terraform lo detecte:

```bash
docker stop mlflow-dev
terraform plan -var-file=dev.tfvars
```

**Observa:** Terraform nota que el contenedor no está corriendo y propone recrearlo.
Corre `terraform apply` y vuelve al estado deseado. Esto es *desired-state* vs. imperativo.

### TODO 3 — Ambientes con tfvars

Levanta un segundo stack `prod` aislado, en paralelo al `dev`:

```bash
terraform apply -var-file=prod.tfvars
```

**Observa:** dos stacks completos coexistiendo (puertos 5001/9010/9011), generados por
**el mismo código**. Cambió solo el `-var-file`. Recuerda hacer `destroy` de ambos al final.

Con ambos stacks corriendo, entrena contra uno u otro pasando `--tracking-uri`:

```bash
python ml/train.py --tracking-uri http://localhost:5000   # dev
python ml/train.py --tracking-uri http://localhost:5001   # prod
```

(También puedes definir la variable de entorno `MLFLOW_TRACKING_URI` en vez del flag.)

### TODO 4 — Refactor a módulos *(avanzado)*

Extrae el storage (Postgres + MinIO + bucket) a un módulo `modules/storage` y MLflow a
`modules/mlflow`. El `main.tf` raíz debería quedar como dos llamadas `module { ... }`.
**Observa:** el `plan` no debe cambiar nada de infra — solo reorganizaste el código.

> **Solución:** rama [`solucion-todo-4-5`](../../tree/solucion-todo-4-5). El código quedó en
> `terraform/modules/storage` y `terraform/modules/mlflow`, y el `main.tf` raíz llama a ambos
> módulos. Como los recursos cambian de dirección (de `docker_container.mlflow` pasan a
> `module.mlflow.docker_container.mlflow`), se agregaron bloques `moved { ... }` al final de
> `main.tf`: si ya tenías el stack `dev` levantado con el código anterior, ejecuta
> `terraform plan -var-file=dev.tfvars` sobre esta rama y confirma que da **"No changes"**
> (o solo el remapeo de estado, sin destruir/recrear nada).

### TODO 5 — Agrega un servicio *(abierto)*

Extiende el stack con una pieza más para practicar composición. Opciones:
- un contenedor de **model serving** (`mlflow models serve`), o
- **Prometheus + Grafana** para monitoreo básico.

> **Solución:** rama [`solucion-todo-4-5`](../../tree/solucion-todo-4-5). Se eligió la opción de
> **model serving**: un módulo `terraform/modules/serving` (opcional, controlado por la
> variable `enable_serving`) que corre `mlflow models serve` contra un modelo del **Model
> Registry**. Requiere dos pasos:
>
> ```bash
> # 1) entrena y registra el modelo "iris-clf" en el registry (train.py ahora hace
> #    mlflow.sklearn.log_model(..., registered_model_name="iris-clf"))
> python ml/train.py --tracking-uri http://localhost:5000
>
> # 2) levanta el servicio de serving apuntando a esa versión registrada
> cd terraform
> terraform apply -var-file=dev.tfvars -var="enable_serving=true"
> ```
>
> **Observa:** `terraform output serving_url` te da la URL de la API REST del modelo
> (`POST /invocations`). El puerto es configurable con `serving_port` (5002 en dev, 5012 en
> prod) para poder correr serving de ambos ambientes en paralelo, igual que en TODO 3.
>
> Pruébalo con `curl` (4 features de iris, en el orden que espera el modelo):
>
> ```bash
> curl -X POST http://localhost:5002/invocations \
>   -H "Content-Type: application/json" \
>   -d '{
>     "dataframe_split": {
>       "columns": ["sepal length (cm)", "sepal width (cm)", "petal length (cm)", "petal width (cm)"],
>       "data": [[5.1, 3.5, 1.4, 0.2]]
>     }
>   }'
> ```
>
> Debería responder algo como `{"predictions": [0]}` (la clase de iris predicha).
>
> ⚠️ **En Codespaces** el `curl` de arriba solo funciona ejecutado *desde una terminal dentro
> del Codespace* (ahí `localhost:5002` sí llega al contenedor). Para acceder **desde fuera**
> (tu navegador, o un `curl` desde tu máquina) necesitas la URL que Codespaces genera para el
> puerto — igual que con el 5000 de MLflow. El `.devcontainer/devcontainer.json` ya declara
> `5002` y `5012` en `forwardPorts`/`portsAttributes` (labels *"Model serving (dev/prod)"*),
> así que deberían aparecer solos en la pestaña **PORTS** en cuanto levantas el módulo de
> serving; si no aparecen, agrégalos a mano ahí (botón **Add Port**) y copia la URL
> generada (ícono del globo) en vez de `localhost`.
>
> **Depuración del contenedor de serving.** Si el `curl` falla o el contenedor se cae, mira
> sus logs (funciona igual en Codespaces, es Docker normal):
>
> ```bash
> docker logs serving-dev          # o --tail 100 / -f para seguirlo en vivo
> docker ps -a --filter name=serving
> ```
>
> Causas típicas:
> - **`model_version` inexistente**: `var.serving_model_version` (default `"1"`) no coincide
>   con la versión real registrada para `iris-clf`. Confirma el número en el Model Registry
>   de la UI de MLflow y pásalo con `-var="serving_model_version=N"`.
> - **Versiones de dependencias**: el `serving.Dockerfile` está fijado a las versiones con
>   las que se entrena el modelo (`scikit-learn==1.7.2`, `numpy==2.2.6`, `scipy==1.15.3`) y a
>   un `fastapi`/`starlette` compatibles con el scoring server de `mlflow==2.22.5`. Si dejas
>   esas dependencias sin fijar, pip instala lo último y el server falla con
>   `AttributeError: 'FastAPI' object has no attribute 'route'` (starlette 1.x rompe a mlflow
>   2.22.5). Si cambias las versiones de `ml/requirements.txt`, mantén el Dockerfile sincronizado.
>
> Nota: Terraform no siempre reconstruye la imagen al cambiar el Dockerfile. Si editaste
> `serving.Dockerfile`, fuerza la reconstrucción:
>
> ```bash
> docker rmi -f mlflow-serving:local
> terraform apply -var-file=dev.tfvars -var="enable_serving=true" -replace='module.serving[0].docker_container.serving'
> ```

---

## Al terminar: LIMPIA

```bash
make clean   # destruye dev y prod de una vez
# o bien, uno por uno:
cd terraform
terraform destroy -var-file=dev.tfvars
terraform destroy -var-file=prod.tfvars   # si levantaste prod
```

**Plan A (Codespaces):** además, borra el Codespace desde
github.com/codespaces → tu Codespace → **Delete**. Un Codespace detenido igual consume
tu cuota de almacenamiento. (Borrar recursos que ya no usas es, justamente, la lección.)
