# 🚀 GKE Hello World con Terraform

Crea un clúster de **Google Kubernetes Engine (GKE)** con **Terraform** y publica una mini página web accesible desde internet. En unos 15 minutos y con muy poco código.

Pensado para aprender: cada paso explica **qué** hace y **por qué**.

```
Internet ──► Load Balancer de Google (IP pública)
                 │
                 ▼
          ┌─────────────── Clúster GKE Autopilot ───────────────┐
          │   Service "web" (LoadBalancer) ──► Pod nginx :80    │
          │                                    └─ index.html    │
          └─────────────────────────────────────────────────────┘
```

---

## 📁 Qué hay en este repo

| Archivo     | Qué hace |
|-------------|----------|
| `main.tf`   | Terraform: activa la API de GKE y crea un clúster **Autopilot** llamado `gke-demo`. |
| `app.yaml`  | Kubernetes: la página HTML (ConfigMap), el servidor nginx (Deployment) y la IP pública (Service). |

> **¿Qué es Autopilot?** Un modo de GKE en el que Google gestiona los nodos (las máquinas). Tú solo despliegas tu app y pagas por los recursos que piden tus pods. Es la forma más simple de empezar.

---

## ✅ Requisitos

1. Una cuenta de [Google Cloud](https://console.cloud.google.com/) con un **proyecto** y la **facturación activada**. Los usuarios nuevos tienen créditos gratis.
2. Tener instaladas estas herramientas:

| Herramienta | Instalación (macOS con Homebrew) | Otras plataformas |
|-------------|----------------------------------|-------------------|
| gcloud CLI  | `brew install --cask gcloud-cli` | [docs](https://cloud.google.com/sdk/docs/install) |
| Terraform   | `brew install terraform`         | [docs](https://developer.hashicorp.com/terraform/install) |
| kubectl     | `brew install kubectl`           | [docs](https://kubernetes.io/docs/tasks/tools/) |

3. El plugin de autenticación de GKE, que kubectl necesita para hablar con el clúster:

```bash
gcloud components install gke-gcloud-auth-plugin
```

---

## 🛠️ Paso a paso

### 1. Iniciar sesión en Google Cloud

```bash
gcloud auth login                       # para gcloud y kubectl
gcloud auth application-default login   # para Terraform
```

### 2. Elegir tu proyecto

Busca el ID de tu proyecto:

```bash
gcloud projects list
```

Guárdalo en una variable. Los siguientes comandos la usan:

```bash
export PROJECT_ID=tu-proyecto-id
gcloud config set project $PROJECT_ID
gcloud auth application-default set-quota-project $PROJECT_ID
```

### 3. Crear el clúster con Terraform ⏱️ unos 5–10 min

```bash
terraform init                                # descarga el provider de Google
terraform plan  -var="project_id=$PROJECT_ID" # muestra qué va a crear (2 recursos)
terraform apply -var="project_id=$PROJECT_ID" # lo crea (escribe "yes")
```

### 4. Conectar kubectl al clúster

```bash
gcloud container clusters get-credentials gke-demo --region us-central1 --project $PROJECT_ID
```

> En Autopilot, `kubectl get nodes` puede salir vacío al principio. Es normal: los nodos aparecen cuando despliegas algo.

### 5. Desplegar la web

```bash
kubectl apply -f app.yaml
kubectl get pods                  # espera a que salga "Running" (1–2 min)
kubectl get service web --watch   # espera a que EXTERNAL-IP tenga una IP, luego Ctrl+C
```

### 6. Probarla 🎉

```bash
curl http://$(kubectl get service web -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

O abre `http://<EXTERNAL-IP>` en el navegador. Deberías ver **"Hola desde GKE 🚀"**.

**Reto:** cambia el texto de `index.html` en `app.yaml` y ejecuta:

```bash
kubectl apply -f app.yaml
kubectl rollout restart deployment web
```

---

## 🧹 Borrar todo (¡no te lo saltes!)

El orden **importa**:

```bash
# 1. Borra la app. Esto libera el Load Balancer y la IP pública.
kubectl delete -f app.yaml

# 2. Destruye el clúster
terraform destroy -var="project_id=$PROJECT_ID"

# 3. Comprueba que no queda nada (todas deberían salir vacías)
gcloud compute forwarding-rules list --project $PROJECT_ID
gcloud container clusters list       --project $PROJECT_ID
gcloud compute disks list            --project $PROJECT_ID
```

> **¿Por qué primero `kubectl delete`?** El Load Balancer **no lo creó Terraform**: lo creó GKE al ver el `Service` de tipo `LoadBalancer`. Si destruyes el clúster primero, el balanceador puede quedarse huérfano y seguir cobrando.

---

## 💰 ¿Cuánto cuesta?

- **Gestión del clúster**: el nivel gratuito de GKE cubre un clúster Autopilot (o zonal) por cuenta de facturación.
- **El pod** (0,25 vCPU y 256 MiB): céntimos por hora.
- **El Load Balancer**: unos 0,025 $/hora.

Una tarde de pruebas sale por muy poco. Dejarlo encendido semanas, no. Borra todo al terminar.

---

## 🧠 Conceptos que aprendes

| Concepto | Dónde lo ves |
|----------|--------------|
| **Infraestructura como código** | `main.tf`: el clúster se crea, se versiona y se destruye con código. |
| **ConfigMap** | Guarda el `index.html` y lo monta como archivo dentro del contenedor. |
| **Deployment** | Mantiene vivo el pod de nginx. Si se cae, Kubernetes lo recrea. |
| **Service `LoadBalancer`** | Pide a Google Cloud un balanceador externo (capa 4) con una IP pública. |
| **NodePort** | El `80:3xxxx/TCP` de `kubectl get svc`: el balanceador envía el tráfico a ese puerto de los nodos y kube-proxy lo lleva al pod. |

Puedes ver el balanceador en la consola, en **Network services → Load balancing**, o con:

```bash
gcloud compute forwarding-rules list
```

---

## ❓ Problemas comunes

| Síntoma | Causa / solución |
|---------|------------------|
| `EXTERNAL-IP` se queda en `<pending>` | Espera 2–3 min. Google está creando el balanceador. |
| El pod está en `Pending` | Normal en Autopilot durante 1–2 min mientras crea un nodo. |
| Errores en rojo en Cloud Logging | nginx escribe sus `[notice]` por stderr y Cloud Logging lo marca como ERROR. El `404 favicon.ico` es el navegador pidiendo el icono de la pestaña. Ninguno es un fallo real. |
| `WARNING: ... quota project` | Ejecuta `gcloud auth application-default set-quota-project $PROJECT_ID`. |
| `gke-gcloud-auth-plugin not found` | Instálalo (ver Requisitos) y abre una terminal nueva. |
| Error de API o facturación en `terraform apply` | Activa la facturación del proyecto en la consola de Google Cloud. |

---

## 📚 Siguientes pasos

- Gestionar también la app con Terraform (provider `kubernetes`).
- Usar **Ingress / Gateway API** con dominio propio y HTTPS (certificados gestionados).
- Guardar el estado de Terraform en un bucket de **GCS** (backend remoto).
- Escalar con `kubectl scale deployment web --replicas=3`.
