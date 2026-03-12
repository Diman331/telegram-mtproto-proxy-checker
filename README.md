# Telegram MTProto Proxy Checker

A Node.js CLI tool that verifies Telegram MTProto proxies by actually communicating with Telegram servers using the official TDLib API.

## Features

- ✅ **Real Verification**: Verifies proxies by actually communicating with Telegram servers, not just TCP connections
- ✅ **Uses TDLib**: Official Telegram Database Library API (`addProxy` and `pingProxy` methods)
- ✅ **No Authorization Required**: Works before login - no phone number or bot token needed
- ✅ **Multiple URL Formats**: Supports both `tg://proxy?` and `https://t.me/proxy?` formats
- ✅ **Smart Secret Handling**: Auto-detects and converts hex/base64 secrets
- ✅ **Detailed Error Messages**: Shows specific failure reasons (connection refused, timeout, invalid secret, etc.)
- ✅ **Scriptable**: Proper exit codes for automation
- ✅ **Cross-Platform**: Works on Windows, Linux, and macOS
- ✅ **Telegram Bot**: Built-in bot for easy proxy verification via Telegram

## Установка

### Быстрая установка (рекомендуется)

```bash
curl -sL https://raw.githubusercontent.com/Diman331/telegram-mtproto-proxy-checker/master/install-auto.sh | bash
```

Или скачайте и запустите вручную:

```bash
chmod +x install-auto.sh
./install-auto.sh
```

### Ручная установка

```bash
# Клонируйте репозиторий
git clone https://github.com/Diman331/telegram-mtproto-proxy-checker.git
cd telegram-mtproto-proxy-checker

# Установите зависимости
npm install

# Настройте переменные окружения
cp .env.example .env
nano .env  # Добавьте TELEGRAM_BOT_TOKEN и ADMIN_ID

# Запустите бота
npm run bot
```

### Через меню управления

```bash
./manage.sh
```

Меню позволит:
- 📝 Добавить/изменить токен бота
- 👤 Добавить/изменить Admin ID
- 🔄 Обновить бота из GitHub
- 🚀 Запустить/остановить бота
- 📊 Просмотреть статус
- 🗑️ Удалить бота

### Полная установка с автозапуском

```bash
chmod +x install.sh
./install.sh
```

Этот скрипт предоставит меню с вариантами:
- **1) Install** - Установка бота
- **2) Update** - Обновление до последней версии
- **3) Uninstall** - Удаление бота и данных
- **4) Exit** - Выход

При установке скрипт:
- Установит все системные зависимости
- Установит npm пакеты
- Создаст .env файл
- Предложит настроить автозапуск через systemd

## Telegram Bot

Этот проект включает Telegram-бота для удобной проверки прокси прямо в мессенджере.

### Настройка бота

1. **Получите токен бота:**
   - Откройте [@BotFather](https://t.me/BotFather) в Telegram
   - Отправьте команду `/newbot`
   - Следуйте инструкциям и получите токен

2. **Установите токен в переменную окружения:**
   ```bash
   # Linux/macOS
   export TELEGRAM_BOT_TOKEN="your-bot-token-here"

   # Windows PowerShell
   $env:TELEGRAM_BOT_TOKEN="your-bot-token-here"

   # Windows CMD
   set TELEGRAM_BOT_TOKEN=your-bot-token-here
   ```

3. **Запустите бота:**
   ```bash
   npm run bot
   # или
   node bot.js
   ```

### Использование бота

1. Отправьте боту ссылку на прокси в формате:
   - `tg://proxy?server=...&port=...&secret=...`
   - `https://t.me/proxy?server=...&port=...&secret=...`

2. Бот проверит прокси и ответит:
   - ✅ **Прокси работает** — с задержкой в мс
   - ❌ **Прокси не работает** — с описанием ошибки

### Команды бота

| Команда | Описание |
|---------|----------|
| `/start` | Запустить бота, показать приветствие |
| `/help` | Показать справку по использованию |
| `/ping` | Проверить активность бота |

### Пример ответа бота

**Успех:**
```
✅ Прокси работает!

🔗 Прокси: https://t.me/proxy?server=...
⏱ Задержка: 145 мс
```

**Ошибка:**
```
❌ Прокси не работает

🔗 Прокси: https://t.me/proxy?server=...
⚠️ Ошибка: Proxy server refused the connection
```

**Несколько прокси (пакетная проверка):**
```
📊 Результаты проверки

Всего: 5
✅ Работает: 3
❌ Не работает: 2

Детали:
✅ tg://proxy?server=1.2.3.4... — 120 мс
❌ tg://proxy?server=5.6.7.8... — CONNECTION_REFUSED
✅ https://t.me/proxy?server=9.10.11.12... — 89 мс
❌ https://t.me/proxy?server=13.14.15.16... — TIMEOUT
✅ tg://proxy?server=17.18.19.20... — 245 мс
```

## Особенности бота

- **Парсинг из текста**: Бот автоматически находит все прокси-ссылки в сообщении
- **Пересланные сообщения**: Поддерживает проверку пересланных сообщений из каналов и чатов
- **Пакетная проверка**: Можно отправить сразу несколько прокси — бот проверит все и выдаст сводный отчёт
- **Поддержка форматов**:
  - `tg://proxy?server=...&port=...&secret=...`
  - `https://t.me/proxy?server=...&port=...&secret=...`
  - `https://t.me/+proxy?server=...&port=...&secret=...`

## Функции бота

- **Парсинг из текста**: Автоматически находит все прокси-ссылки в сообщении
- **Пересланные сообщения**: Поддерживает проверку пересланных сообщений из каналов и чатов
- **Пакетная проверка**: Проверка нескольких прокси сразу с прогресс-баром
- **Кнопка скачивания**: Кнопка для получения файла с рабочими прокси (.txt)
- **База прокси**: Сохранение всех проверенных прокси в базу данных
- **Прогресс-бар**: Визуальный прогресс при проверке большого количества прокси
- **Админ-команда**: `/checkdb` — проверка всей базы прокси с выгрузкой рабочих

## Команды бота

| Команда | Описание |
|---------|----------|
| `/start` | Запустить бота, показать приветствие |
| `/help` | Показать справку по использованию |
| `/ping` | Проверить активность бота |
| `/stats` | Показать статистику базы прокси |
| `/settings` | Настройки автопроверки (админ) |
| `/chkdb` | Проверить всю базу прокси (админ) |

## Функции бота

- **Парсинг из текста**: Автоматически находит все прокси-ссылки в сообщении
- **Пересланные сообщения**: Поддерживает проверку пересланных сообщений из каналов и чатов
- **Пакетная проверка**: Проверка нескольких прокси сразу с прогресс-баром
- **Кнопка скачивания**: Кнопка для получения файла с рабочими прокси (.txt)
- **База прокси**: Сохранение всех проверенных прокси в базу данных
- **Прогресс-бар**: Визуальный прогресс при проверке большого количества прокси
- **Автопроверка**: Автоматическая проверка базы по расписанию
- **Очистка базы**: Автоматическое удаление нерабочих прокси каждые 2 проверки
- **Настройки**: Гибкая настройка интервала автопроверки (6-168 часов)

## Настройка админ-доступа

Для использования админ-команд необходимо установить `ADMIN_ID`:

1. Узнайте свой Telegram ID через [@userinfobot](https://t.me/userinfobot)
2. Установите переменную окружения:
   ```bash
   export ADMIN_ID="ваш_user_id"
   ```

## Автозапуск бота

Смотрите инструкцию в файле [AUTO_START.md](AUTO_START.md)

### Быстрая настройка systemd

```bash
# Создайте службу
sudo nano /etc/systemd/system/telegram-proxy-bot.service

# Вставьте содержимое из AUTO_START.md
# Замените пути и переменные

# Включите и запустите
sudo systemctl daemon-reload
sudo systemctl enable telegram-proxy-bot
sudo systemctl start telegram-proxy-bot

# Проверка
sudo systemctl status telegram-proxy-bot
```

## Usage

### Basic Usage

**Command line argument:**
```bash
node index.js "https://t.me/proxy?server=IP&port=PORT&secret=SECRET"
```

**Using tg:// format:**
```bash
node index.js "tg://proxy?server=IP&port=PORT&secret=SECRET"
```

**From stdin:**
```bash
# Linux/macOS
echo "https://t.me/proxy?server=IP&port=PORT&secret=SECRET" | node index.js

# Windows PowerShell
"https://t.me/proxy?server=IP&port=PORT&secret=SECRET" | node index.js
```

**Debug mode (detailed output):**
```bash
node index.js --debug "https://t.me/proxy?server=IP&port=PORT&secret=SECRET"
```

## Output

### Success
```
OK
```

### Failure with Detailed Error
```
NO: CONNECTION_REFUSED: Proxy server refused the connection (server might be down or port is closed)
NO: DNS_ERROR: Cannot resolve server hostname to IP address
NO: TIMEOUT: Proxy did not respond within 15 seconds
NO: Response hash mismatch
NO: INVALID_SECRET: Secret format is invalid or incorrect
```

### Invalid Secret Format
```
INVALID_SECRET
```

## Exit Codes

- `0` - Proxy verification successful (OK)
- `1` - Invalid secret format (INVALID_SECRET)
- `2` - Proxy verification failed (NO with detailed error)

## Examples

### Example 1: Working Proxy
```bash
$ node index.js "https://t.me/proxy?server=163.5.31.10&port=8443&secret=EERighJJvXrFGRMCIMJdCQRueWVrdGFuZXQuY29tZmFyYWthdi5jb212YW4ubmFqdmEuY29tAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
OK
```

### Example 2: Failed Proxy
```bash
$ node index.js "https://t.me/proxy?server=invalid.example.com&port=443&secret=abcd1234"
NO: DNS_ERROR: Cannot resolve server hostname to IP address
```

### Example 3: Debug Mode
```bash
$ node index.js --debug "https://t.me/proxy?server=example.com&port=443&secret=secret123"
[DEBUG] Parsed URL:
[DEBUG]   Server: example.com
[DEBUG]   Port: 443
[DEBUG]   Secret (raw): secret123...
[DEBUG]   Secret format: base64
[DEBUG] Connected to TDLib
[DEBUG] Server: example.com
[DEBUG] Port: 443
[DEBUG] Secret (hex, first 32 chars): b2b9b2b9b2b9b2b9b2b9b2b9b2b9b2b9...
[DEBUG] Secret length: 9 bytes
NO: CONNECTION_REFUSED: Proxy server refused the connection
```

## How It Works

1. **URL Parsing**: Extracts `server`, `port`, and `secret` from the proxy URL
2. **Secret Normalization**:
   - If secret contains only hex characters `[0-9a-fA-F]`, treats it as hex
   - Otherwise, treats it as URL-safe Base64
   - Normalizes Base64: `-` → `+`, `_` → `/`
   - Adds padding (`=`) to make length a multiple of 4
   - Decodes to raw bytes and converts to lowercase hex string
3. **TDLib Client**: Creates a TDLib client (no authorization required)
4. **Add Proxy**: Calls `addProxy` with the normalized secret
5. **Ping Proxy**: Calls `pingProxy` to verify actual connectivity to Telegram servers
6. **Result**: Returns success or detailed error message

## Error Messages Explained

| Error Message | Meaning |
|--------------|---------|
| `CONNECTION_REFUSED` | Proxy server is not accepting connections (down or firewall blocking) |
| `DNS_ERROR` | Cannot resolve the server hostname |
| `TIMEOUT` | Proxy did not respond within 15 seconds |
| `Response hash mismatch` | Proxy is reachable but secret is incorrect or proxy misconfigured |
| `INVALID_SECRET` | Secret format cannot be decoded (invalid hex or base64) |
| `INVALID_PORT` | Port number is invalid or out of range |
| `INVALID_SERVER` | Server address is invalid |

## Requirements

- **Node.js** ≥ 18
- **Platform**: Windows, Linux, or macOS (TDLib binaries are platform-specific)
- **Internet Connection**: Required for initial TDLib download and proxy verification

## Technical Details

- Uses TDLib's `addProxy` and `pingProxy` methods
- Proxy verification works **before authorization** (no login required)
- Timeout is set to 15 seconds for proxy ping
- Supports long Fake-TLS Base64 secrets
- Automatically handles both hex and base64 secret formats
- TDLib binaries are automatically downloaded via `prebuilt-tdlib` package

## Troubleshooting

### "Dynamic Loading Error: Win32 error 126"
- Ensure `prebuilt-tdlib` package is installed: `npm install prebuilt-tdlib`
- On Windows, the `tdjson.dll` will be automatically downloaded

### "Cannot find module 'tdl'"
- Run `npm install` to install all dependencies

### Proxy verification times out
- Check if the proxy server is accessible
- Verify the server IP/hostname and port are correct
- Some proxies may have longer response times - this is normal

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details


