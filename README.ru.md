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

- Docker
- Docker Compose

### Установка

1. Склонируйте или скопируйте файлы проекта на локальную машину

2. Запустите сервисы:
   ```bash
   docker-compose up -d
   ```

3. Дождитесь подключения воркера (проверьте логи):
   ```bash
   docker-compose logs -f jenkins-worker
   ```

## Конфигурация

### Переменные окружения

Следующие переменные окружения можно настроить в `docker-compose.yml`:

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `JENKINS_MASTER_SERVER` | `jenkins-master:8080` | Имя хоста и порт Jenkins master |
| `JENKINS_USER` | (обязательно) | Имя пользователя администратора Jenkins |
| `JENKINS_PASSWORD` | (обязательно) | Пароль администратора Jenkins |
| `JENKINS_AGENT_NAME` | `jnlp-agent` | Имя агента в Jenkins |

### Учетные данные по умолчанию

В настройках Jenkins по умолчанию используются:
- Имя пользователя: `admin`
- Пароль: `admin`

**Важно**: Измените эти учетные данные в production средах!

## Как это работает

### 1. Ожидание Jenkins Master

Скрипт воркера сначала ждет, пока master станет доступен:
```bash
until curl -sf "${JENKINS_URL}" >/dev/null 2>&1; do
  sleep 5
done
```

### 2. Получение CSRF Crumb

Jenkins требует crumb для POST запросов. Скрипт получает его:
```bash
CRUMB=$(curl -sf -c cookies.txt "${JENKINS_MASTER_URL}/crumbIssuer/api/json" | jq -r '.crumb')
```

### 3. Регистрация агента

Скрипт проверяет, существует ли агент уже. Если нет, регистрирует нового агента через Jenkins API:
```bash
curl -X POST "${JENKINS_MASTER_URL}/computer/doCreateItem?name=${AGENT_NAME}&type=hudson.slaves.DumbSlave"
```

### 4. Получение секрета агента

После регистрации скрипт получает секретный токен агента:
```bash
SECRET=$(curl -sf "${JENKINS_MASTER_URL}/computer/${AGENT_NAME}/slave-agent.jnlp"  | xmlstarlet sel -t -v '(//argument)[1]')
```

### 5. Загрузка и запуск агента

Скрипт загружает `agent.jar` и запускает агента:
```bash
java -jar agent.jar \
  -url "${JENKINS_URL}" \
  -secret "${SECRET}" \
  -name "${AGENT_NAME}" \
  -webSocket \
  -workDir "/home/jenkins"
```

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

## Устранение неполадок

### Воркер не может подключиться к Master

1. Проверьте, что оба контейнера находятся в одной Docker сети:
   ```bash
   docker network inspect jenkins-network
   ```

2. Убедитесь, что Jenkins master запущен:
   ```bash
   docker-compose ps
   ```

3. Проверьте логи Jenkins master:
   ```bash
   docker-compose logs jenkins-master
   ```

### Агент уже существует

Если агент уже зарегистрирован, скрипт пропустит регистрацию и использует существующего агента.

### Ошибка получения секрета

1. Проверьте правильность имени агента
2. Проверьте логи Jenkins master на ошибки регистрации
3. Убедитесь, что агент правильно зарегистрирован в Jenkins

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
    - JENKINS_USER=admin
    - JENKINS_PASSWORD=admin
    - JENKINS_AGENT_NAME=worker-2
  volumes:
    - jenkins-worker-2-home:/var/jenkins_home
  networks:
    - jenkins-network
  depends_on:
    - jenkins-master
  restart: unless-stopped
```

### Изменение конфигурации агента

Отредактируйте JSON payload в `entrypoint.sh` для настройки:
- Количество исполнителей
- Путь к удаленной файловой системе
- Метки (labels)
- Настройки рабочей директории

## Лицензия

Этот проект предоставляется "как есть" для образовательных и разработческих целей.

## Кредиты

Этот проект был создан и поддерживается с помощью AI-ассистента **Qwen3-Coder-Next**.