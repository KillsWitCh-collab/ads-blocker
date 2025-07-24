set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Пожалуйста, запустите этот скрипт с правами root или через sudo."
  exit 1
fi

echo "🗑️ Начинаем удаление ads-blocker..."

# Шаг 1: Остановка и отключение службы
echo "⚙️ Отключаем системную службу..."
systemctl stop dns-blocker.service || true
systemctl disable dns-blocker.service || true
systemctl daemon-reload

# Шаг 2: Восстановление DNS
echo "🔧 Восстанавливаем оригинальные настройки DNS..."
if [ -f /etc/resolv.conf.backup-ads-blocker ]; then
  chattr -i /etc/resolv.conf 2>/dev/null || true
  mv /etc/resolv.conf.backup-ads-blocker /etc/resolv.conf
else
  echo "Резервная копия resolv.conf не найдена. Возможно, вам придется настроить DNS вручную."
fi

# Шаг 3: Удаление файлов
echo "📑 Удаляем файлы программы..."
rm -f /etc/systemd/system/dns-blocker.service
rm -f /usr/local/bin/ads-blocker
rm -rf /etc/dns-blocker

echo "✅ Удаление успешно завершено."