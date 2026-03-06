# Автозапуск бота через systemd

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
WorkingDirectory=/root/telegram-mtproto-proxy-checker-1
Environment="TELEGRAM_BOT_TOKEN=your-bot-token"
Environment="ADMIN_ID=your-telegram-id"
ExecStart=/usr/bin/node bot.js
Restart=always
RestartSec=10

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

Для изменения токена или ADMIN_ID отредактируйте службу:

```bash
sudo systemctl edit telegram-proxy-bot
```

Добавьте:

```ini
[Service]
Environment="TELEGRAM_BOT_TOKEN=new-token"
Environment="ADMIN_ID=new-admin-id"
```

Затем перезапустите:

```bash
sudo systemctl daemon-reload
sudo systemctl restart telegram-proxy-bot
```

## 5. Файлы бота

После запуска бот создаст следующие файлы:
- `proxies_db.json` - база данных прокси
- `bot_settings.json` - настройки автопроверки

Эти файлы сохраняются автоматически и не требуют настройки.
