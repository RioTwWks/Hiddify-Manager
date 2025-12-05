# Docker Cleanup Instructions

## Удаление Docker данных

Если нужно удалить данные Docker (например, после тестирования), выполните следующие команды:

### 1. Остановить и удалить контейнеры и volumes

```bash
cd /path/to/hiddify-manager
docker compose down -v
```

### 2. Удалить файлы данных (требуются права root)

Файлы в `docker-data/` создаются от имени root, поэтому для их удаления нужны права sudo:

```bash
# Удалить только данные
sudo rm -rf docker-data/

# Или удалить всю папку hiddify-manager
sudo rm -rf /path/to/hiddify-manager
```

### 3. Удалить Docker images (опционально)

```bash
# Посмотреть все images
docker images

# Удалить конкретный image
docker rmi <image_id>

# Удалить все неиспользуемые images
docker image prune -a
```

### 4. Полная очистка Docker (опционально)

```bash
# Удалить все неиспользуемые ресурсы
docker system prune -a --volumes
```

**Внимание:** Последняя команда удалит все неиспользуемые контейнеры, сети, images и volumes!

