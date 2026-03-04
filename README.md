# Инструкция по публикации Helm-чарта в Nexus и обновлению CI/CD пайплайна

## 1. Публикация Helm-чарта в Nexus Repository

### 1.1. Создание репозитория в Nexus

1. Войдите в Nexus по адресу: `https://nexus.praktikum-services.tech`
2. Перейдите в **Settings** → **Repositories**
3. Нажмите **Create repository**
4. Выберите тип рецепта: **helm (hosted)**
5. Заполните параметры:
   - **Name**: `sausage-store-helm-<ваше_имя>-<ваша_фамилия>`
   - **Online**: ✓ (включено)
   - **Deployment policy**: Allow redeploy
6. Нажмите **Create repository**

### 1.2. Подготовка чарта к публикации

```bash
# Перейдите в директорию чарта
cd sausage-store-chart

# Упакуйте чарт
helm package .

# Создайте индекс репозитория (опционально, для локальной проверки)
helm repo index . --url https://nexus.praktikum-services.tech/repository/sausage-store-helm-<ваше_имя>-<ваша_фамилия>/
```

### 1.3. Загрузка чарта в Nexus

```bash
# Загрузите чарт с помощью curl
curl -u <ваш_логин>:<ваш_пароль> \
  --upload-file sausage-store-0.1.0.tgz \
  https://nexus.praktikum-services.tech/repository/sausage-store-helm-<ваше_имя>-<ваша_фамилия>/
```

Или используйте Helm push (требуется плагин helm-push):

```bash
# Добавьте репозиторий
helm repo add nexus https://nexus.praktikum-services.tech/repository/sausage-store-helm-<ваше_имя>-<ваша_фамилия>/ \
  --username <ваш_логин> \
  --password <ваш_пароль>

# Запушьте чарт
helm push sausage-store-0.1.0.tgz nexus
```

---

## 2. Обновление CI/CD пайплайна для работы с Helm

### 2.1. Пример .gitlab-ci.yml с использованием Helm

```yaml
stages:
  - build
  - test
  - deploy

variables:
  NEXUS_HELM_REPO: https://nexus.praktikum-services.tech/repository/sausage-store-helm-<ваше_имя>-<ваша_фамилия>/
  HELM_VERSION: "3.12.0"

build:
  stage: build
  script:
    - echo "Building application components..."
    - docker build -t $CI_REGISTRY_IMAGE/sausage-backend:$CI_COMMIT_SHA ./backend
    - docker build -t $CI_REGISTRY_IMAGE/sausage-backend-report:$CI_COMMIT_SHA ./backend-report
    - docker build -t $CI_REGISTRY_IMAGE/sausage-frontend:$CI_COMMIT_SHA ./frontend
    - docker push $CI_REGISTRY_IMAGE/sausage-backend:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE/sausage-backend-report:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE/sausage-frontend:$CI_COMMIT_SHA

test:
  stage: test
  script:
    - echo "Running tests..."
    - pytest tests/

deploy:
  stage: deploy
  image: alpine/helm:3.12.0
  script:
    - |
      # Создание Kubeconfig
      mkdir -p ~/.kube
      echo "$KUBECONFIG" | base64 -d > ~/.kube/config
      
      # Добавление Helm-репозитория Nexus
      helm repo add nexus $NEXUS_HELM_REPO
      helm repo update
      
      # Установка/обновление релиза
      helm upgrade --install sausage-store \
        nexus/sausage-store-chart \
        --set environment=test \
        --set global.imageRegistry=$CI_REGISTRY \
        --set backend.image.tag=$CI_COMMIT_SHA \
        --set backendReport.image.tag=$CI_COMMIT_SHA \
        --set frontend.image.tag=$CI_COMMIT_SHA \
        --set frontend.ingress.fqdn="std-mcpro-20.k8s.praktikum-services.tech" \
        --set backend.replicaCount=2 \
        --set frontend.replicaCount=2 \
        --set backendReport.replicaCount=1 \
        --atomic \
        --timeout 15m \
        --namespace sausage-store \
        --create-namespace
  
  environment:
    name: test
    url: https://ivanov-ivan-01.k8s.praktikum-services.tech
  
  only:
    - main
    - master

deploy-production:
  stage: deploy
  image: alpine/helm:3.12.0
  script:
    - |
      # Создание Kubeconfig
      mkdir -p ~/.kube
      echo "$KUBECONFIG_PROD" | base64 -d > ~/.kube/config
      
      # Добавление Helm-репозитория Nexus
      helm repo add nexus $NEXUS_HELM_REPO
      helm repo update
      
      # Установка/обновление релиза в production
      helm upgrade --install sausage-store \
        nexus/sausage-store-chart \
        --set environment=production \
        --set global.imageRegistry=$CI_REGISTRY \
        --set backend.image.tag=$CI_COMMIT_SHA \
        --set backendReport.image.tag=$CI_COMMIT_SHA \
        --set frontend.image.tag=$CI_COMMIT_SHA \
        --set frontend.ingress.fqdn="sausage-store.k8s.praktikum-services.tech" \
        --set backend.replicaCount=3 \
        --set frontend.replicaCount=3 \
        --set backendReport.replicaCount=2 \
        --set backend.resources.requests.cpu="200m" \
        --set backend.resources.limits.cpu="1000m" \
        --atomic \
        --timeout 20m \
        --namespace sausage-store-prod \
        --create-namespace
  
  environment:
    name: production
    url: https://sausage-store.k8s.praktikum-services.tech
  
  when: manual
  only:
    - main
    - master
```

---

## 3. Переменные для переопределения при установке

### Основные переменные:

| Параметр | Описание | Пример |
|----------|----------|--------|
| `environment` | Окружение (test/production) | `test` |
| `global.imageRegistry` | Реестр образов | `gitlab.praktikum-services.ru:5050` |
| `backend.image.tag` | Тэг образа backend | `v1.2.3` |
| `frontend.ingress.fqdn` | Домен для Ingress | `myapp.k8s.praktikum-services.tech` |
| `backend.replicaCount` | Количество реплик backend | `2` |
| `frontend.replicaCount` | Количество реплик frontend | `2` |
| `backendReport.replicaCount` | Количество реплик backendReport | `1` |
| `vault.address` | Адрес Vault | `https://vault.praktikum-services.tech` |
| `database.connectionString` | Строка подключения к БД | `postgresql://user:pass@host:5432/db` |

### Пример команды установки:

```bash
helm upgrade --install sausage-store \
  nexus/sausage-store-chart \
  --set environment=test \
  --set fqdn="ivanov-ivan-01.k8s.praktikum-services.tech" \
  --atomic \
  --timeout 15m
```

---

## 4. Проверка установки

```bash
# Проверка статуса релиза
helm status sausage-store

# Проверка установленных ресурсов
kubectl get all -n sausage-store

# Проверка логов
kubectl logs -l app.kubernetes.io/part-of=sausage-store -n sausage-store

# Тестирование доступа
curl https://ivanov-ivan-01.k8s.praktikum-services.tech
```

---

## 5. Структура файлов чарта

```
sausage-store-chart/
├── Chart.yaml                 # Основной манифест чарта
├── values.yaml                # Значения по умолчанию
└── charts/
    ├── backend/
    │   ├── Chart.yaml
    │   └── templates/
    │       ├── configmap.yaml
    │       ├── deployment.yaml
    │       ├── secrets.yaml
    │       └── service.yaml
    ├── backendReport/
    │   ├── Chart.yaml
    │   └── templates/
    │       ├── configmap.yaml
    │       ├── deployment.yaml
    │       └── secrets.yaml
    └── frontend/
        ├── Chart.yaml
        └── templates/
            ├── configmap.yaml
            ├── deployment.yaml
            ├── ingress.yaml
            ├── secrets.yaml
            └── service.yaml
```
