#!/bin/bash

# Скрипт для настройки SSL сертификатов для n8n
# Запрашивает сертификат, исправляет права доступа и настраивает docker-compose.yml
# Объединенная версия: включает функциональность setup-ssl.sh и fix-ssl-permissions.sh

set -e

echo "=========================================="
echo "Настройка SSL сертификатов для n8n"
echo "=========================================="

# Создаем директорию для сертификатов
SSL_DIR="/tmp/ssl"

# Функция для исправления прав доступа
fix_permissions() {
    echo ""
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
    
    # Исправляем права на файлы сертификатов, если они существуют
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
    echo "Проверка прав доступа:"
    ls -la "$SSL_DIR" 2>/dev/null || sudo ls -la "$SSL_DIR"
    
    # Проверяем доступность для чтения
    if [ -f "$SSL_DIR/cert.pem" ] && [ -f "$SSL_DIR/key.pem" ]; then
        if [ -r "$SSL_DIR/cert.pem" ] && [ -r "$SSL_DIR/key.pem" ]; then
            echo ""
            echo "✓ Сертификаты доступны для чтения"
            return 0
        else
            echo ""
            echo "⚠ Ошибка: Файлы недоступны для чтения"
            return 1
        fi
    else
        return 1
    fi
}

# Проверяем и исправляем права доступа для существующих сертификатов
if [ -d "$SSL_DIR" ] && [ -f "$SSL_DIR/cert.pem" ] && [ -f "$SSL_DIR/key.pem" ]; then
    echo ""
    echo "Обнаружены существующие сертификаты. Проверка прав доступа..."
    fix_permissions
    
    if [ $? -eq 0 ]; then
        echo ""
        read -p "Сертификаты уже существуют. Получить новые? (y/n): " replace_certs
        if [ "$replace_certs" != "y" ]; then
            echo ""
            echo "✓ Используются существующие сертификаты"
            echo "✓ Права доступа проверены и исправлены"
            echo ""
            echo "=========================================="
            echo "Готово! Можно перезапустить контейнеры:"
            echo "  docker compose restart n8n"
            echo "=========================================="
            exit 0
        fi
    fi
else
    # Создаем директорию, если её нет
    mkdir -p "$SSL_DIR"
fi

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
        
        # Устанавливаем права доступа для чтения контейнером
        chmod 644 "$SSL_DIR/cert.pem"
        chmod 644 "$SSL_DIR/key.pem"
        chmod 755 "$SSL_DIR"
        
        echo "✓ Сертификаты скопированы в $SSL_DIR/"
        ;;
    2)
        read -p "Введите домен для сертификата (например, 158.160.123.159.nip.io): " domain
        
        if [ -z "$domain" ]; then
            echo "Ошибка: Домен не указан"
            exit 1
        fi
        
        read -p "Введите ваш email адрес для Let's Encrypt (для уведомлений о истечении сертификата): " email
        
        if [ -z "$email" ]; then
            echo "Ошибка: Email адрес не указан"
            exit 1
        fi
        
        # Простая проверка формата email
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo "Ошибка: Неверный формат email адреса: $email"
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
        echo "Домен: $domain"
        echo "Email: $email"
        echo "Убедитесь, что порт 80 свободен и домен указывает на этот сервер!"
        read -p "Продолжить? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo "Отменено"
            exit 0
        fi
        
        # Останавливаем n8n если запущен (чтобы освободить порт 80)
        docker compose down n8n 2>/dev/null || true
        
        # Получаем сертификат
        sudo certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email "$email" || {
            echo "Ошибка при получении сертификата"
            exit 1
        }
        
        # Копируем сертификаты
        CERT_SOURCE="/etc/letsencrypt/live/$domain/fullchain.pem"
        KEY_SOURCE="/etc/letsencrypt/live/$domain/privkey.pem"
        
        # Проверяем существование файлов с sudo, так как они в защищенной директории
        if ! sudo test -f "$CERT_SOURCE" || ! sudo test -f "$KEY_SOURCE"; then
            echo "Ошибка: Сертификаты не найдены в /etc/letsencrypt/live/$domain/"
            exit 1
        fi
        
        sudo cp "$CERT_SOURCE" "$SSL_DIR/cert.pem"
        sudo cp "$KEY_SOURCE" "$SSL_DIR/key.pem"
        # Устанавливаем права доступа для чтения контейнером
        sudo chmod 644 "$SSL_DIR/cert.pem"
        sudo chmod 644 "$SSL_DIR/key.pem"
        # Делаем директорию доступной для чтения
        sudo chmod 755 "$SSL_DIR"
        
        echo "✓ Сертификаты получены и скопированы в $SSL_DIR/"
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

# Исправляем права доступа после получения сертификатов
echo ""
fix_permissions

echo ""
echo "=========================================="
echo "Настройка завершена!"
echo "=========================================="
echo ""
echo "Сертификаты находятся в: $SSL_DIR/"
echo "  - cert.pem (сертификат)"
echo "  - key.pem (приватный ключ)"
echo ""
echo "Права доступа настроены корректно"
echo ""
echo "Проверка docker-compose.yml..."
if grep -q "N8N_SSL_CERT" docker-compose.yml && grep -q "/tmp/ssl:/etc/ssl/n8n" docker-compose.yml; then
    echo "✓ docker-compose.yml уже настроен для SSL"
else
    echo "⚠ Внимание: docker-compose.yml не содержит настроек SSL"
    echo "Убедитесь, что добавлены:"
    echo "  - N8N_SSL_CERT и N8N_SSL_KEY в environment"
    echo "  - /tmp/ssl:/etc/ssl/n8n:ro в volumes"
fi
echo ""
echo "Следующие шаги:"
echo "1. Убедитесь, что в .env установлено:"
echo "   N8N_PROTOCOL=https"
echo "   N8N_SECURE_COOKIE=true"
echo "   WEBHOOK_URL=https://158.160.123.159.nip.io/"
echo ""
echo "2. Перезапустите контейнеры:"
echo "   docker compose restart n8n"
echo "   или"
echo "   docker compose down && docker compose up -d"
echo ""

