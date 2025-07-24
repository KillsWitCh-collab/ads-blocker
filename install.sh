# Останавливаем скрипт в случае любой ошибки
set -e

# Проверяем, что скрипт запущен от имени root
if [ "$(id -u)" -ne 0 ]; then
  echo "Пожалуйста, запустите этот скрипт с правами root или через sudo."
  exit 1
fi

echo "🚀 Начинаем установку ads-blocker v1.0.0..."

# Определяем архитектуру системы
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
  echo "Ошибка: Архитектура ARM64 (aarch64) пока не поддерживается."
  exit 1
fi

# Переменные
REPO="KillsWitCh-collab/ads-blocker"
TAG="v1.0.0"
BINARY_NAME="ads-blocker-linux-${ARCH}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${BINARY_NAME}"

CONFIG_DIR="/etc/dns-blocker"
BIN_PATH="/usr/local/bin/ads-blocker"

# Шаг 1: Скачивание готового бинарного файла
echo "🌐 Скачиваем готовую программу..."
curl -sL "$DOWNLOAD_URL" -o "$BIN_PATH"
chmod +x "$BIN_PATH" # Делаем файл исполняемым

# Шаг 2: Создание папок и скачивание конфигов
echo "📑 Создаем конфигурационные файлы..."
mkdir -p "$CONFIG_DIR/blacklists"

# Скачиваем конфиг и списки по-отдельности
curl -sL "https://raw.githubusercontent.com/${REPO}/main/config.yaml" -o "$CONFIG_DIR/config.yaml"
curl -sL "https://raw.githubusercontent.com/${REPO}/main/blacklists/ads.txt" -o "$CONFIG_DIR/blacklists/ads.txt"
curl -sL "https://raw.githubusercontent.com/${REPO}/main/blacklists/trackers.txt" -o "$CONFIG_DIR/blacklists/trackers.txt"

# Шаг 3: Создание службы systemd (код остался тем же)
SERVICE_FILE="/etc/systemd/system/dns-blocker.service"
echo "⚙️ Создаем системную службу (systemd)..."

cat <<EOF > $SERVICE_FILE
[Unit]
Description=DNS Ad Blocker
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
ExecStart=$BIN_PATH
WorkingDirectory=$CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF

# Шаг 4: Настройка DNS системы (код остался тем же)
echo "🔧 Настраиваем системный DNS..."
if [ ! -f /etc/resolv.conf.backup-ads-blocker ]; then
  cp /etc/resolv.conf /etc/resolv.conf.backup-ads-blocker
fi
chattr -i /etc/resolv.conf 2>/dev/null || true
echo "nameserver 127.0.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf

# Шаг 5: Запуск службы
echo "✅ Включаем и запускаем службу..."
systemctl daemon-reload
systemctl enable dns-blocker.service > /dev/null
systemctl start dns-blocker.service

echo "🎉 Установка успешно завершена! Блокировщик активен."
echo "Чтобы посмотреть логи, используйте: journalctl -u dns-blocker -f"
