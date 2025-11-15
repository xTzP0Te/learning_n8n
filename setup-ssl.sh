#!/bin/bash

# Скрипт для настройки SSL сертификатов для n8n
# Запрашивает сертификат и настраивает docker-compose.yml

set -e

echo "=========================================="
echo "Настройка SSL сертификатов для n8n"
echo "=========================================="

# Создаем директорию для сертификатов
SSL_DIR="/tmp/ssl"
mkdir -p "$SSL_DIR"

echo ""
echo "Выберите способ получения сертификата:"
echo "1) Указать пути к существующим файлам сертификата"
echo "2) Использовать certbot для получения Let's Encrypt сертификата"
read -p "Ваш выбор (1 или 2): " choice

case $choice in
    1)
        echo ""
        read -p "Введите путь к файлу сертификата (cert.pem или fullchain.pem): " cert_path
        read -p "Введите путь к файлу приватного ключа (key.pem или privkey.pem): " key_path
        
        if [ ! -f "$cert_path" ]; then
            echo "Ошибка: Файл сертификата не найден: $cert_path"
            exit 1
        fi
        
        if [ ! -f "$key_path" ]; then
            echo "Ошибка: Файл ключа не найден: $key_path"
            exit 1
        fi
        
        # Копируем сертификаты
        cp "$cert_path" "$SSL_DIR/cert.pem"
        cp "$key_path" "$SSL_DIR/key.pem"
        
        echo "✓ Сертификаты скопированы в $SSL_DIR/"
        ;;
    2)
        read -p "Введите домен для сертификата (например, 158.160.123.159.nip.io): " domain
        
        if [ -z "$domain" ]; then
            echo "Ошибка: Домен не указан"
            exit 1
        fi
        
        # Проверяем наличие certbot
        if ! command -v certbot &> /dev/null; then
            echo "Certbot не установлен. Установка..."
            sudo apt-get update
            sudo apt-get install -y certbot
        fi
        
        echo ""
        echo "Получение сертификата через certbot..."
        echo "Убедитесь, что порт 80 свободен и домен указывает на этот сервер!"
        read -p "Продолжить? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo "Отменено"
            exit 0
        fi
        
        # Останавливаем n8n если запущен (чтобы освободить порт 80)
        docker compose down n8n 2>/dev/null || true
        
        # Получаем сертификат
        sudo certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email admin@example.com || {
            echo "Ошибка при получении сертификата"
            exit 1
        }
        
        # Копируем сертификаты
        CERT_SOURCE="/etc/letsencrypt/live/$domain/fullchain.pem"
        KEY_SOURCE="/etc/letsencrypt/live/$domain/privkey.pem"
        
        if [ ! -f "$CERT_SOURCE" ] || [ ! -f "$KEY_SOURCE" ]; then
            echo "Ошибка: Сертификаты не найдены в /etc/letsencrypt/live/$domain/"
            exit 1
        fi
        
        sudo cp "$CERT_SOURCE" "$SSL_DIR/cert.pem"
        sudo cp "$KEY_SOURCE" "$SSL_DIR/key.pem"
        sudo chown $USER:$USER "$SSL_DIR/cert.pem" "$SSL_DIR/key.pem"
        sudo chmod 644 "$SSL_DIR/cert.pem"
        sudo chmod 600 "$SSL_DIR/key.pem"
        
        echo "✓ Сертификаты получены и скопированы в $SSL_DIR/"
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

# Проверяем права доступа
chmod 644 "$SSL_DIR/cert.pem"
chmod 600 "$SSL_DIR/key.pem"

echo ""
echo "=========================================="
echo "Проверка docker-compose.yml..."
echo "=========================================="

# Проверяем, что docker-compose.yml содержит настройки SSL
if grep -q "N8N_SSL_CERT" docker-compose.yml && grep -q "/tmp/ssl:/etc/ssl/n8n" docker-compose.yml; then
    echo "✓ docker-compose.yml уже настроен для SSL"
else
    echo "⚠ Внимание: docker-compose.yml не содержит настроек SSL"
    echo "Убедитесь, что добавлены:"
    echo "  - N8N_SSL_CERT и N8N_SSL_KEY в environment"
    echo "  - /tmp/ssl:/etc/ssl/n8n:ro в volumes"
fi

echo ""
echo "=========================================="
echo "Настройка завершена!"
echo "=========================================="
echo ""
echo "Сертификаты находятся в: $SSL_DIR/"
echo "  - cert.pem (сертификат)"
echo "  - key.pem (приватный ключ)"
echo ""
echo "docker-compose.yml обновлен для использования SSL"
echo ""
echo "Следующие шаги:"
echo "1. Убедитесь, что в .env установлено:"
echo "   N8N_PROTOCOL=https"
echo "   N8N_SECURE_COOKIE=true"
echo "   WEBHOOK_URL=https://158.160.123.159.nip.io/"
echo ""
echo "2. Перезапустите контейнеры:"
echo "   docker compose down && docker compose up -d"
echo ""

