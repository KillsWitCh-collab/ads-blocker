# Останавливаем скрипт в случае любой ошибки
set -e

# Проверяем, что скрипт запущен от имени root
if [ "$(id -u)" -ne 0 ]; then
  echo "Пожалуйста, запустите этот скрипт с правами root или через sudo."
  exit 1
fi

echo "🚀 Начинаем установку ads-blocker..."

# Шаг 1: Установка зависимостей (Go для компиляции и Git для скачивания)
echo "📦 Устанавливаем необходимые пакеты (git, golang-go)..."
apt-get update > /dev/null
apt-get install -y git golang-go > /dev/null

# Шаг 2: Клонирование репозитория
REPO_URL="https://github.com/KillsWitCh-collab/ads-blocker.git"
INSTALL_DIR="/opt/ads-blocker-source"
echo "🌐 Клонируем репозиторий из $REPO_URL..."
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
fi
git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null

# Шаг 3: Компиляция проекта
echo "🛠️ Компилируем проект..."
cd "$INSTALL_DIR"
go build -o ads-blocker .

# Шаг 4: Установка файлов в систему
CONFIG_DIR="/etc/dns-blocker"
BIN_PATH="/usr/local/bin/ads-blocker"

echo "📑 Копируем файлы..."
# Копируем бинарный файл
install -m 755 ads-blocker /usr/local/bin/

# Создаем папку для конфигов и списков
mkdir -p "$CONFIG_DIR/blacklists"
# Копируем конфиг и списки
cp config.yaml "$CONFIG_DIR/"
cp -r blacklists/* "$CONFIG_DIR/blacklists/"

# Шаг 5: Создание службы systemd
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

# Шаг 6: Настройка DNS системы
echo "🔧 Настраиваем системный DNS..."
# Делаем резервную копию текущих настроек
if [ ! -f /etc/resolv.conf.backup-ads-blocker ]; then
  cp /etc/resolv.conf /etc/resolv.conf.backup-ads-blocker
fi
# Устанавливаем наш локальный DNS и делаем файл неизменяемым
chattr -i /etc/resolv.conf 2>/dev/null || true
echo "nameserver 127.0.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf

# Шаг 7: Запуск службы
echo "✅ Включаем и запускаем службу..."
systemctl daemon-reload
systemctl enable dns-blocker.service > /dev/null
systemctl start dns-blocker.service

# Очистка
rm -rf "$INSTALL_DIR"

echo "🎉 Установка успешно завершена! Блокировщик активен."
echo "Чтобы посмотреть логи, используйте: journalctl -u dns-blocker -f"