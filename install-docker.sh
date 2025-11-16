#!/bin/bash

# Скрипт установки Docker Engine на Ubuntu
# Основан на официальной документации: https://docs.docker.com/engine/install/ubuntu/

set -e  # Остановка при ошибке

echo "=========================================="
echo "Установка Docker Engine на Ubuntu"
echo "=========================================="

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "Ошибка: Скрипт должен быть запущен с правами root (используйте sudo)"
    exit 1
fi

# Определение версии Ubuntu
. /etc/os-release
echo "Обнаружена ОС: $ID $VERSION_ID"

# Шаг 1: Удаление старых версий Docker
echo ""
echo "Шаг 1: Удаление старых версий Docker..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Шаг 2: Обновление пакетов
echo ""
echo "Шаг 2: Обновление списка пакетов..."
apt-get update

# Шаг 3: Установка зависимостей
echo ""
echo "Шаг 3: Установка зависимостей..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Шаг 4: Добавление официального GPG ключа Docker
echo ""
echo "Шаг 4: Добавление GPG ключа Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Шаг 5: Настройка репозитория
echo ""
echo "Шаг 5: Настройка репозитория Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Шаг 6: Обновление списка пакетов после добавления репозитория
echo ""
echo "Шаг 6: Обновление списка пакетов..."
apt-get update

# Шаг 7: Установка Docker Engine, CLI, containerd и Docker Compose
echo ""
echo "Шаг 7: Установка Docker Engine, CLI, containerd и Docker Compose..."
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Шаг 8: Проверка статуса Docker
echo ""
echo "Шаг 8: Проверка статуса Docker..."
systemctl status docker --no-pager || systemctl start docker

# Шаг 9: Проверка установки
echo ""
echo "Шаг 9: Проверка установки Docker..."
docker --version
docker compose version

# Шаг 10: Запуск тестового контейнера
echo ""
echo "Шаг 10: Запуск тестового контейнера hello-world..."
docker run hello-world

echo ""
echo "=========================================="
echo "Docker успешно установлен!"
echo "=========================================="
echo ""
echo "Версия Docker:"
docker --version
echo ""
echo "Версия Docker Compose:"
docker compose version
echo ""
echo "Для запуска Docker без sudo добавьте пользователя в группу docker:"
echo "  sudo usermod -aG docker \$USER"
echo "  newgrp docker"
echo ""

