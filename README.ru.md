# Настройка Jenkins Worker

Этот проект предоставляет решение на основе Docker для автоматического подключения Jenkins агентов (воркеров) к Jenkins master без использования веб-интерфейса. Вся настройка и регистрация агентов выполняется через скрипты и переменные окружения.

## Обзор

Решение состоит из:
- **Jenkins Master** - Основной сервер Jenkins, который координирует сборки и задачи
- **Jenkins Worker** - Docker контейнер, который автоматически регистрируется как агент и подключается к master

## Архитектура

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Docker Network                               │
│                                                                     │
│  ┌──────────────────┐         ┌──────────────────┐                 │
│  │  Jenkins Master  │────────>│  Jenkins Worker  │                 │
│  │  (jenkins-master)│  API    │  (jenkins-worker)│                 │
│  │                  │         │                  │                 │
│  │  - Web UI: 8080  │         │  - Registers as  │                 │
│  │  - Agent Port:   │         │    agent via API │                 │
│  │    50000         │         │  - Downloads     │                 │
│  └──────────────────┘         │    agent.jar     │                 │
│                               │  - Connects via  │                 │
│                               │    JNLP          │                 │
│                               └──────────────────┘                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Быстрый старт

### Предварительные требования

- Docker Compose

### Установка

1. Склонируйте или скопируйте файлы проекта на локальную машину

2. Запустите сервисы:
   ```bash
   docker-compose up --build -d
   ```

3. Дождитесь подключения воркера (проверьте логи):
   ```bash
   docker-compose logs jenkins-worker -f
   ```

## Конфигурация

### Переменные окружения

Следующие переменные окружения можно настроить в `docker-compose.yml`:

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `JENKINS_MASTER_SERVER` | `jenkins-master:8080` | Имя хоста и порт Jenkins master |
| `JENKINS_AGENT_NAME` | `jnlp-agent` | Имя агента в Jenkins |

## Структура файлов

```
jenkins-worker/
├── Dockerfile           # Определение Docker образа
├── entrypoint.sh        # Основной скрипт для регистрации агента
└── README.md            # Этот файл

jenkins-master/
├── Dockerfile           # Dockerfile для Jenkins master
├── plugins.txt          # Список плагинов для установки
└── README.md            # Документация по настройке master

docker-compose.yml       # Оркестрация сервисов
```

## Кастомизация

### Добавление дополнительных воркеров

Добавьте дополнительные сервисы в `docker-compose.yml`:
```yaml
jenkins-worker-2:
  build:
    context: ./jenkins-worker
    dockerfile: Dockerfile
  container_name: jenkins-worker-2
  environment:
    - JENKINS_AGENT_NAME=worker-2
  volumes:
    - jenkins-worker-2-home:/var/jenkins_home
  networks:
    - jenkins-network
  depends_on:
    - jenkins-master
  restart: unless-stopped
```

Этот проект предоставляется "как есть" для образовательных и разработческих целей.

## Кредиты

Этот проект был создан с помощью и, одновременно, вопреки стараниям AI-ассистента **Qwen3-Coder-Next** :)