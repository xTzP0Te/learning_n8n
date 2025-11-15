#!/bin/bash

# Скрипт для исправления прав доступа к SSL сертификатам
# Полезно при клонировании репозитория на новую виртуалку

set -e

SSL_DIR="/tmp/ssl"

echo "=========================================="
echo "Исправление прав доступа к SSL сертификатам"
echo "=========================================="

if [ ! -d "$SSL_DIR" ]; then
    echo "Директория $SSL_DIR не существует. Создаю..."
    mkdir -p "$SSL_DIR"
    echo "✓ Директория создана"
fi

# Исправляем права на директорию
echo "Исправление прав на директорию $SSL_DIR..."
if [ -w "$SSL_DIR" ]; then
    chmod 755 "$SSL_DIR" 2>/dev/null || sudo chmod 755 "$SSL_DIR"
else
    sudo chmod 755 "$SSL_DIR"
fi
echo "✓ Права на директорию: 755"

# Исправляем права на файлы сертификатов
if [ -f "$SSL_DIR/cert.pem" ]; then
    echo "Исправление прав на cert.pem..."
    if [ -w "$SSL_DIR/cert.pem" ]; then
        chmod 644 "$SSL_DIR/cert.pem" 2>/dev/null || sudo chmod 644 "$SSL_DIR/cert.pem"
    else
        sudo chmod 644 "$SSL_DIR/cert.pem"
    fi
    echo "✓ Права на cert.pem: 644"
else
    echo "⚠ Файл cert.pem не найден"
fi

if [ -f "$SSL_DIR/key.pem" ]; then
    echo "Исправление прав на key.pem..."
    if [ -w "$SSL_DIR/key.pem" ]; then
        chmod 644 "$SSL_DIR/key.pem" 2>/dev/null || sudo chmod 644 "$SSL_DIR/key.pem"
    else
        sudo chmod 644 "$SSL_DIR/key.pem"
    fi
    echo "✓ Права на key.pem: 644"
else
    echo "⚠ Файл key.pem не найден"
fi

# Проверяем итоговые права
echo ""
echo "=========================================="
echo "Проверка прав доступа:"
echo "=========================================="
ls -la "$SSL_DIR" 2>/dev/null || sudo ls -la "$SSL_DIR"

# Проверяем доступность для чтения
if [ -f "$SSL_DIR/cert.pem" ] && [ -f "$SSL_DIR/key.pem" ]; then
    if [ -r "$SSL_DIR/cert.pem" ] && [ -r "$SSL_DIR/key.pem" ]; then
        echo ""
        echo "✓ Сертификаты доступны для чтения"
        echo "✓ Права доступа исправлены успешно"
    else
        echo ""
        echo "⚠ Ошибка: Файлы недоступны для чтения"
        exit 1
    fi
else
    echo ""
    echo "⚠ Сертификаты не найдены в $SSL_DIR"
    echo "Запустите setup-ssl.sh для получения сертификатов"
fi

echo ""
echo "=========================================="
echo "Готово! Теперь можно перезапустить контейнеры:"
echo "  docker compose restart n8n"
echo "=========================================="

