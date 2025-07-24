Простой и эффективный блокировщик рекламы на уровне DNS 🛡️

Этот проект позволяет заблокировать рекламу, трекеры и вредоносные сайты на уровне всей операционной системы (Windows, macOS, Linux). Он работает как локальный DNS-сервер, который сверяется с черными списками и не даёт программам получить IP-адреса заблокированных доменов.

КАК УСТАНОВИТЬ (ДЛЯ LINUX DEBIAN/UBUNTU)

Откройте терминал и введите одну команду. Скрипт всё сделает за вас.
bash <(curl -sL https://raw.githubusercontent.com/KillsWitCh-collab/ads-blocker/main/install.sh)

КАК УДАЛИТЬ

bash <(curl -sL https://raw.githubusercontent.com/KillsWitCh-collab/ads-blocker/main/uninstall.sh)

КАК НАСТРОИТЬ

После установки все файлы конфигурации находятся в папке /etc/dns-blocker/.
- Чтобы добавить новые списки блокировки, просто положите свой .txt файл в папку /etc/dns-blocker/blacklists/
- Чтобы изменить DNS-сервер для перенаправления (например, на Cloudflare 1.1.1.1), отредактируйте файл /etc/dns-blocker/config.yaml
После любого изменения конфигурации перезапустите службу командой:
sudo systemctl restart dns-blocker

КАК ПОСМОТРЕТЬ ЛОГИ

sudo journalctl -u dns-blocker -f

Этот проект создан с любовью и желанием сделать интернет чище! ❤️