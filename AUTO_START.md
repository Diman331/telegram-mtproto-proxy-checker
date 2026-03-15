# Автозапуск бота через systemd

## Быстрая установка через скрипт

Вместо ручной настройки можно использовать скрипт установки:

```bash
./install.sh
```

Выберите опцию **1) Install** и согласитесь на настройку systemd.

Или используйте быструю установку:

```bash
curl -sL https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/master/install-auto.sh | bash
```

## Ручная настройка

## 1. Создайте службу systemd

```bash
sudo nano /etc/systemd/system/telegram-proxy-bot.service
```

Вставьте следующее содержимое (замените `/path/to/bot` на путь к боту):

```ini
[Unit]
Description=Telegram MTProto Proxy Checker Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/bot
EnvironmentFile=/path/to/bot/.env
ExecStart=/usr/bin/node /path/to/bot/bot.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## 2. Включите и запустите службу

```bash
# Перезагрузите systemd
sudo systemctl daemon-reload

# Включите автозапуск
sudo systemctl enable telegram-proxy-bot

# Запустите бота
sudo systemctl start telegram-proxy-bot

# Проверьте статус
sudo systemctl status telegram-proxy-bot
```

## 3. Полезные команды

```bash
# Просмотр логов
sudo journalctl -u telegram-proxy-bot -f

# Перезапуск бота
sudo systemctl restart telegram-proxy-bot

# Остановка бота
sudo systemctl stop telegram-proxy-bot

# Отключение автозапуска
sudo systemctl disable telegram-proxy-bot
```

## 4. Настройка переменных окружения

Для изменения токена или ADMIN_ID отредактируйте файл `.env`:

```bash
nano .env
```

Затем перезапустите службу:

```bash
sudo systemctl restart telegram-proxy-bot
```

## 5. Файлы бота

После запуска бот создаст следующие файлы:
- `proxies_db.json` - база данных прокси
- `bot_settings.json` - настройки автопроверки

Эти файлы сохраняются автоматически и не требуют настройки.

## 6. Обновление и удаление

### Обновление через скрипт:
```bash
./install.sh
# Выбрать опцию 2) Update
```

### Обновление вручную:
```bash
git pull
npm install
sudo systemctl restart telegram-proxy-bot
```

### Удаление через скрипт:
```bash
./install.sh
# Выбрать опцию 3) Uninstall
```

### Удаление вручную:
```bash
# Остановить службу
sudo systemctl stop telegram-proxy-bot
sudo systemctl disable telegram-proxy-bot
sudo rm /etc/systemd/system/telegram-proxy-bot.service
sudo systemctl daemon-reload

# Удалить файлы
rm -rf node_modules
rm -f proxies_db.json bot_settings.json .env
```
