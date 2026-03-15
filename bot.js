#!/usr/bin/env node

// Load environment variables from .env
require('dotenv').config();

const path = require('path');
const { Telegraf, Markup } = require('telegraf');
const tdl = require('tdl');
const fs = require('fs');
const { getTdjson } = require('prebuilt-tdlib');

// Configure tdl to use prebuilt TDLib
tdl.configure({ tdjson: getTdjson() });

// Get bot token from environment variable
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const ADMIN_ID = process.env.ADMIN_ID; // Admin user ID for database check command

if (!BOT_TOKEN) {
  console.error('Error: TELEGRAM_BOT_TOKEN environment variable is not set');
  console.error('Please set it: export TELEGRAM_BOT_TOKEN="your-bot-token"');
  process.exit(1);
}

// Database file for storing verified proxies
const DB_FILE = path.join(__dirname, 'proxies_db.json');
const SETTINGS_FILE = path.join(__dirname, 'bot_settings.json');

// In-memory storage for temporary working proxies (for download button)
const tempWorkingProxies = new Map(); // chat_id -> { proxies, timestamp }

// Bot settings
let botSettings = {
  autoCheckEnabled: false,
  autoCheckIntervalHours: 24,
  lastAutoCheck: null,
  dbCheckCount: 0
};

// Load proxies database
function loadProxiesDB() {
  try {
    if (fs.existsSync(DB_FILE)) {
      const data = fs.readFileSync(DB_FILE, 'utf-8');
      return JSON.parse(data);
    }
  } catch (error) {
    console.error('Error loading proxies DB:', error);
  }
  return { proxies: {} };
}

// Save proxies database
function saveProxiesDB(db) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2), 'utf-8');
  } catch (error) {
    console.error('Error saving proxies DB:', error);
  }
}

// Load bot settings
function loadSettings() {
  try {
    if (fs.existsSync(SETTINGS_FILE)) {
      const data = fs.readFileSync(SETTINGS_FILE, 'utf-8');
      botSettings = { ...botSettings, ...JSON.parse(data) };
      console.log('[SETTINGS] Loaded:', botSettings);
    }
  } catch (error) {
    console.error('Error loading settings:', error);
  }
}

// Save bot settings
function saveSettings() {
  try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(botSettings, null, 2), 'utf-8');
  } catch (error) {
    console.error('Error saving settings:', error);
  }
}

// Add proxy to database
function addProxyToDB(db, url, status, latency = null) {
  db.proxies[url] = {
    checked_at: new Date().toISOString(),
    status: status ? 'working' : 'failed',
    latency: latency
  };
  saveProxiesDB(db);
}

// Remove failed proxies from database
function removeFailedProxies() {
  const db = loadProxiesDB();
  const beforeCount = Object.keys(db.proxies).length;
  const failedProxies = Object.keys(db.proxies).filter(url => db.proxies[url].status === 'failed');
  
  failedProxies.forEach(url => {
    delete db.proxies[url];
  });
  
  saveProxiesDB(db);
  
  return {
    before: beforeCount,
    after: beforeCount - failedProxies.length,
    removed: failedProxies.length
  };
}

// Store working proxies for download
function storeWorkingProxies(chatId, proxies) {
  tempWorkingProxies.set(chatId, {
    proxies,
    timestamp: Date.now()
  });
  // Clean up after 1 hour
  setTimeout(() => {
    tempWorkingProxies.delete(chatId);
  }, 3600000);
}

// Get working proxies for download
function getWorkingProxies(chatId) {
  const data = tempWorkingProxies.get(chatId);
  if (!data) return null;
  // Check if not expired (1 hour)
  if (Date.now() - data.timestamp > 3600000) {
    tempWorkingProxies.delete(chatId);
    return null;
  }
  return data.proxies;
}

// Create bot instance
const bot = new Telegraf(BOT_TOKEN);

// Parse proxy URL from tg:// or https://t.me/proxy format
function parseProxyUrl(url) {
  const tgPattern = /^tg:\/\/proxy\?/;
  const httpsPattern = /^https?:\/\/(www\.)?t\.me\/proxy\?/;

  if (!tgPattern.test(url) && !httpsPattern.test(url)) {
    throw new Error('Invalid proxy URL format');
  }

  const params = new URLSearchParams(url.split('?')[1]);
  const server = params.get('server');
  const port = parseInt(params.get('port'), 10);
  const secret = params.get('secret');

  if (!server || !port || !secret) {
    throw new Error('Missing required parameters: server, port, or secret');
  }

  if (isNaN(port) || port < 1 || port > 65535) {
    throw new Error('Invalid port number');
  }

  return { server, port, secret };
}

// Normalize secret: detect hex vs base64, decode, convert to hex
function normalizeSecret(secret) {
  const hexPattern = /^[0-9a-fA-F]+$/;
  const isHex = hexPattern.test(secret);

  let bytes;

  if (isHex) {
    if (secret.length % 2 !== 0) {
      throw new Error('INVALID_SECRET');
    }
    try {
      bytes = Buffer.from(secret, 'hex');
    } catch (error) {
      throw new Error('INVALID_SECRET');
    }
  } else {
    let normalized = secret.replace(/-/g, '+').replace(/_/g, '/');
    const padding = normalized.length % 4;
    if (padding !== 0) {
      normalized += '='.repeat(4 - padding);
    }
    try {
      bytes = Buffer.from(normalized, 'base64');
    } catch (error) {
      throw new Error('INVALID_SECRET');
    }
  }

  return bytes.toString('hex').toLowerCase();
}

// Extract detailed error message from TDLib error
function extractErrorMessage(error) {
  let errorMsg = 'Unknown error';
  const errorStr = JSON.stringify(error);

  if (error.response) {
    const response = error.response;

    if (response._ === 'error') {
      const code = response.code;
      const msg = response.message || '';
      errorMsg = `Error ${code}: ${msg}`;

      if (code === 400) {
        const lowerMsg = msg.toLowerCase();
        if (lowerMsg.includes('secret')) {
          errorMsg = 'INVALID_SECRET: Secret format is invalid or incorrect';
        } else if (lowerMsg.includes('port')) {
          errorMsg = 'INVALID_PORT: Port number is invalid or out of range';
        } else if (lowerMsg.includes('server') || lowerMsg.includes('hostname')) {
          errorMsg = 'INVALID_SERVER: Server address is invalid or unreachable';
        } else {
          errorMsg = `INVALID_PROXY: ${msg}`;
        }
      } else if (code === 406 || code === 401) {
        errorMsg = 'CONNECTION_FAILED: Could not establish connection to proxy server';
      } else if (code === 500 || code === 503) {
        errorMsg = 'PROXY_ERROR: Proxy server returned an error or is unavailable';
      } else {
        errorMsg = `Error ${code}: ${msg || 'Unknown TDLib error'}`;
      }
    } else if (typeof response === 'string') {
      errorMsg = response;
    } else if (response.error) {
      errorMsg = response.error.message || JSON.stringify(response.error);
    } else if (response.message) {
      errorMsg = response.message;
    }
  }

  if (error.message) {
    const msg = error.message;

    if (msg.includes('Timeout') || msg.includes('timeout')) {
      errorMsg = 'TIMEOUT: Proxy did not respond within 15 seconds';
    } else if (msg.includes('ECONNREFUSED') || msg.includes('Connection refused')) {
      errorMsg = 'CONNECTION_REFUSED: Proxy server refused the connection (server might be down or port is closed)';
    } else if (msg.includes('ENOTFOUND') || msg.includes('getaddrinfo') || msg.includes('DNS')) {
      errorMsg = 'DNS_ERROR: Cannot resolve server hostname to IP address';
    } else if (msg.includes('ETIMEDOUT') || msg.includes('timed out')) {
      errorMsg = 'TIMEOUT: Connection to proxy server timed out';
    } else if (msg.includes('EHOSTUNREACH') || msg.includes('No route to host')) {
      errorMsg = 'NETWORK_ERROR: No route to proxy server';
    } else if (msg.includes('ECONNRESET') || msg.includes('Connection reset')) {
      errorMsg = 'CONNECTION_RESET: Connection to proxy server was reset';
    } else if (!error.response) {
      errorMsg = msg;
    }
  }

  if (errorMsg === 'Unknown error' && errorStr) {
    const msgMatch = errorStr.match(/"message":\s*"([^"]+)"/);
    if (msgMatch) {
      errorMsg = msgMatch[1];
    } else if (errorStr.length < 200) {
      errorMsg = errorStr;
    }
  }

  return errorMsg;
}

// Verify proxy and return result with latency
async function verifyProxy(server, port, hexSecret) {
  const client = tdl.createClient({
    apiId: 12345,
    apiHash: '0123456789abcdef0123456789abcdef',
    useTestDc: false,
    databaseDirectory: './tdlib-db',
    filesDirectory: './tdlib-files',
  });

  client.on('error', (err) => {
    console.error('[TDLib Error]:', err.message);
  });

  let latency = null;
  let success = false;
  let error = null;

  try {
    // Add proxy
    let addProxyResult;
    try {
      addProxyResult = await client.invoke({
        _: 'addProxy',
        server: server,
        port: port,
        enable: true,
        type: {
          _: 'proxyTypeMtproto',
          secret: hexSecret
        }
      });
    } catch (addProxyError) {
      const errorMsg = extractErrorMessage(addProxyError);
      return {
        success: false,
        latency: null,
        error: errorMsg.includes('INVALID_SECRET') ? 'INVALID_SECRET' : errorMsg
      };
    }

    if (addProxyResult._ !== 'proxy') {
      const errorMsg = extractErrorMessage({ response: addProxyResult });
      return {
        success: false,
        latency: null,
        error: `addProxy failed - ${errorMsg}`
      };
    }

    const proxyId = addProxyResult.id;

    // Ping proxy with latency measurement
    const pingPromise = client.invoke({
      _: 'pingProxy',
      proxy_id: proxyId
    });

    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Timeout')), 15000);
    });

    const startTime = Date.now();
    
    try {
      await Promise.race([pingPromise, timeoutPromise]);
      latency = Date.now() - startTime;
      success = true;
    } catch (pingError) {
      error = extractErrorMessage(pingError);
    }
  } catch (err) {
    error = extractErrorMessage(err);
  } finally {
    try {
      await client.close();
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  return {
    success,
    latency,
    error
  };
}

// Format result message
function formatResult(proxyUrl, result) {
  const { success, latency, error } = result;
  
  // Escape HTML special characters in URL
  const escapedUrl = escapeHtml(proxyUrl);

  if (success) {
    return `<b>✅ Прокси работает!</b>\n\n` +
      `🔗 <a href="${escapedUrl}">Ссылка на прокси</a>\n` +
      `⏱ <b>Задержка:</b> ${latency} мс`;
  } else {
    // Extract short error name
    const shortError = getShortError(error);
    return `<b>❌ Прокси не работает</b>\n\n` +
      `🔗 <a href="${escapedUrl}">Ссылка на прокси</a>\n` +
      `⚠️ <b>Ошибка:</b> ${shortError}`;
  }
}

// Get short error name
function getShortError(error) {
  if (!error) return 'Неизвестная ошибка';
  
  if (error.includes('TIMEOUT')) return 'Таймаут';
  if (error.includes('CONNECTION_REFUSED')) return 'Соединение отклонено';
  if (error.includes('DNS_ERROR')) return 'DNS ошибка';
  if (error.includes('CONNECTION_RESET')) return 'Соединение сброшено';
  if (error.includes('INVALID_SECRET')) return 'Неверный секрет';
  if (error.includes('Connection closed')) return 'Соединение закрыто';
  if (error.includes('Connection failed')) return 'Не удалось подключиться';
  
  // Return first part before colon if exists
  const colonIndex = error.indexOf(':');
  if (colonIndex !== -1) {
    return error.substring(0, colonIndex).trim();
  }
  
  return error;
}

// Escape HTML special characters
function escapeHtml(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Extract proxy URLs from text
function extractProxyUrls(text) {
  const urls = [];
  
  // Pattern for tg://proxy URLs
  const tgPattern = /tg:\/\/proxy\?server=([^&]+)&port=(\d+)&secret=([^\s&]+)/gi;
  // Pattern for https://t.me/proxy URLs
  const httpsPattern = /https?:\/\/(?:www\.)?t\.me\/proxy\?server=([^&]+)&port=(\d+)&secret=([^\s&]+)/gi;
  // Pattern for https://t.me/+proxy URLs (alternative format)
  const httpsPlusPattern = /https?:\/\/(?:www\.)?t\.me\/\+proxy\?server=([^&]+)&port=(\d+)&secret=([^\s&]+)/gi;
  
  let match;
  
  while ((match = tgPattern.exec(text)) !== null) {
    urls.push(`tg://proxy?server=${match[1]}&port=${match[2]}&secret=${match[3]}`);
  }
  
  while ((match = httpsPattern.exec(text)) !== null) {
    urls.push(`https://t.me/proxy?server=${match[1]}&port=${match[2]}&secret=${match[3]}`);
  }
  
  while ((match = httpsPlusPattern.exec(text)) !== null) {
    urls.push(`https://t.me/proxy?server=${match[1]}&port=${match[2]}&secret=${match[3]}`);
  }
  
  // Remove duplicates
  return [...new Set(urls)];
}

// Bot commands
bot.start((ctx) => {
  ctx.reply(
    '👋 Привет! Я бот для проверки MTProto прокси Telegram.\n\n' +
    'Отправьте мне ссылку на прокси или перешлите сообщение с прокси:\n' +
    '• tg://proxy?server=...&port=...&secret=...\n' +
    '• https://t.me/proxy?server=...&port=...&secret=...\n\n' +
    'Я проверю работоспособность и покажу задержку.\n\n' +
    '<i>Поддерживаю множественную проверку — отправьте сразу несколько прокси!</i>',
    { parse_mode: 'HTML' }
  );
});

bot.help((ctx) => {
  ctx.reply(
    '<b>Как использовать:</b>\n\n' +
    '1. Отправьте ссылку на MTProto прокси\n' +
    '2. Перешлите сообщение с прокси\n' +
    '3. Отправьте несколько прокси сразу\n\n' +
    'Я проверю их работоспособность и покажу задержку.\n\n' +
    '<b>Поддерживаемые форматы:</b>\n' +
    '• tg://proxy?...\n' +
    '• https://t.me/proxy?...\n' +
    '• https://t.me/+proxy?...\n\n' +
    '<b>Команды:</b>\n' +
    '/start - Запустить бота\n' +
    '/help - Помощь\n' +
    '/ping - Проверка активности бота\n' +
    '/stats - Статистика базы прокси\n' +
    '/chkdb - Проверить всю базу прокси (админ)\n\n' +
    '<b>Админ:</b>\n' +
    '/chkdb - Проверить всю базу прокси',
    { parse_mode: 'HTML' }
  );
});

bot.command('ping', (ctx) => {
  ctx.reply('🟢 Бот активен! Готов проверять прокси.');
});

// Admin command: check all proxies in database - registered early
console.log('[INIT] Registering /chkdb command');
bot.command('chkdb', async (ctx) => {
  console.log('[chkdb] Command called by user:', ctx.from.id, ctx.from.username);

  // Check if user is admin (if ADMIN_ID is set)
  if (ADMIN_ID && ctx.from.id.toString() !== ADMIN_ID) {
    console.log('[chkdb] Access denied for user:', ctx.from.id);
    return ctx.reply('⛔ У вас нет прав для выполнения этой команды');
  }

  // If ADMIN_ID is not set, warn user
  if (!ADMIN_ID) {
    console.log('[WARNING] /chkdb called without ADMIN_ID set. Anyone can use this command.');
  }

  const db = loadProxiesDB();
  const allProxies = Object.keys(db.proxies);

  console.log('[chkdb] Proxies in DB:', allProxies.length);

  if (allProxies.length === 0) {
    return ctx.reply('📭 База данных пуста');
  }

  const msg = await ctx.reply(`🔍 Проверка базы данных...\nНайдено прокси: ${allProxies.length}\n⏳ Это может занять некоторое время...`);

  const results = [];
  const total = allProxies.length;

  for (let i = 0; i < total; i++) {
    const url = allProxies[i];

    // Update progress every 5 proxies
    if (i % 5 === 0 || i === total - 1) {
      const progress = Math.round(((i + 1) / total) * 100);
      const progressBar = '█'.repeat(Math.floor(progress / 5)) + '░'.repeat(20 - Math.floor(progress / 5));
      await ctx.telegram.editMessageText(
        ctx.chat.id,
        msg.message_id,
        null,
        `🔍 Проверка базы данных...\n\n<code>[${progressBar}] ${progress}%</code>\nПроверено: ${i + 1} из ${total}`,
        { parse_mode: 'HTML' }
      );
    }

    try {
      const { server, port, secret } = parseProxyUrl(url);
      const hexSecret = normalizeSecret(secret);
      const result = await verifyProxy(server, port, hexSecret);

      results.push({
        url,
        success: result.success,
        latency: result.latency,
        error: result.error
      });

      // Update database
      addProxyToDB(db, url, result.success, result.latency);
    } catch (error) {
      results.push({
        url,
        success: false,
        latency: null,
        error: error.message || 'Ошибка'
      });
      addProxyToDB(db, url, false);
    }
  }

  // Send results
  const ok = results.filter(r => r.success).length;
  const fail = results.filter(r => !r.success).length;
  const working = results.filter(r => r.success);

  // Update settings
  botSettings.dbCheckCount = (botSettings.dbCheckCount || 0) + 1;
  botSettings.lastAutoCheck = new Date().toISOString();
  saveSettings();

  let summary = `<b>✅ Проверка базы завершено!</b>\n\n`;
  summary += `<b>Всего:</b> ${total} шт.\n`;
  summary += `<b>✅ Работает:</b> ${ok}\n`;
  summary += `<b>❌ Не работает:</b> ${fail}\n`;
  
  // Remove failed proxies after every 2nd check
  if (botSettings.dbCheckCount % 2 === 0) {
    summary += `\n<b>🧹 Очистка базы...</b>\n`;
    const cleanup = removeFailedProxies();
    summary += `<i>Удалено нерабочих прокси: ${cleanup.removed}</i>\n`;
  }
  
  summary += `\n<i>⚠️ Задержка может отличаться в зависимости от оператора</i>`;

  await ctx.telegram.editMessageText(ctx.chat.id, msg.message_id, null, summary, { parse_mode: 'HTML' });

  // Send working proxies file
  if (working.length > 0) {
    const fileContent = working.map(r => r.url).join('\n');
    const fileName = `proxy_checked_${Date.now()}.txt`;
    const filePath = path.join(__dirname, fileName);

    fs.writeFileSync(filePath, fileContent, 'utf-8');

    await ctx.replyWithDocument({
      source: fs.createReadStream(filePath),
      filename: 'proxy.txt'
    }, {
      caption: `📥 Рабочие прокси из базы (${working.length} шт.)`
    });

    fs.unlinkSync(filePath);
  }
});
console.log('[INIT] /chkdb command registered');

// Stats command
bot.command('stats', async (ctx) => {
  console.log('[stats] Command called by user:', ctx.from.id);
  const db = loadProxiesDB();
  const allProxies = Object.keys(db.proxies);

  const working = allProxies.filter(url => db.proxies[url].status === 'working');
  const failed = allProxies.filter(url => db.proxies[url].status === 'failed');

  let stats = '<b>📊 Статистика базы прокси</b>\n\n';
  stats += `<b>Всего прокси:</b> ${allProxies.length}\n`;
  stats += `<b>✅ Рабочих:</b> ${working.length}\n`;
  stats += `<b>❌ Нерабочих:</b> ${failed.length}\n\n`;

  if (allProxies.length > 0) {
    const lastChecked = Object.values(db.proxies).sort((a, b) =>
      new Date(b.checked_at) - new Date(a.checked_at)
    )[0];
    stats += `<i>Последняя проверка: ${new Date(lastChecked.checked_at).toLocaleString('ru-RU')}</i>`;
  }

  ctx.reply(stats, { parse_mode: 'HTML' });
});

// Auto check settings command
bot.command('settings', async (ctx) => {
  // Check if user is admin
  if (ADMIN_ID && ctx.from.id.toString() !== ADMIN_ID) {
    return ctx.reply('⛔ У вас нет прав для выполнения этой команды');
  }

  const nextCheck = botSettings.autoCheckEnabled
    ? new Date(Date.now() + botSettings.autoCheckIntervalHours * 3600000).toLocaleString('ru-RU')
    : 'Отключена';

  const settingsText = `<b>⚙️ Настройки автопроверки</b>\n\n` +
    `<b>Статус:</b> ${botSettings.autoCheckEnabled ? '✅ Включена' : '❌ Выключена'}\n` +
    `<b>Интервал:</b> ${botSettings.autoCheckIntervalHours} ч.\n` +
    `<b>Следующая проверка:</b> ${nextCheck}\n` +
    `<b>Всего проверок:</b> ${botSettings.dbCheckCount || 0}\n` +
    `<b>Очистка:</b> Каждые 2 проверки\n\n` +
    `<i>Управление кнопками ниже</i>`;

  ctx.reply(settingsText, {
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: '▶️ Включить', callback_data: 'autocheck_enable' },
          { text: '⏸ Выключить', callback_data: 'autocheck_disable' }
        ],
        [
          { text: '➕ +6ч', callback_data: 'autocheck_interval_up' },
          { text: '➖ -6ч', callback_data: 'autocheck_interval_down' }
        ],
        [
          { text: '🔄 Проверить сейчас', callback_data: 'autocheck_run' }
        ]
      ]
    }
  });
});

// Test command to verify bot is responding
bot.command('test', (ctx) => {
  console.log('[test] Command called by user:', ctx.from.id);
  ctx.reply('✅ Бот работает! Команды обрабатываются.');
});

// Check and verify a single proxy URL
async function checkProxyUrl(ctx, proxyUrl, checkMsgId) {
  try {
    const { server, port, secret } = parseProxyUrl(proxyUrl);
    const hexSecret = normalizeSecret(secret);

    const result = await verifyProxy(server, port, hexSecret);
    const formattedResult = formatResult(proxyUrl, result);

    if (checkMsgId) {
      await ctx.telegram.editMessageText(
        ctx.chat.id,
        checkMsgId,
        null,
        formattedResult,
        { parse_mode: 'HTML' }
      );
    } else {
      await ctx.reply(formattedResult, { parse_mode: 'HTML' });
    }
    return result;
  } catch (err) {
    const errorMsg = err.message || 'Неизвестная ошибка';
    const escapedUrl = escapeHtml(proxyUrl);
    const errorText = `<b>❌ Ошибка</b>\n\n🔗 Прокси: <code>${escapedUrl}</code>\n⚠️ ${errorMsg.includes('INVALID_SECRET') ? 'Неверный формат секрета' : escapeHtml(errorMsg)}`;

    if (checkMsgId) {
      await ctx.telegram.editMessageText(ctx.chat.id, checkMsgId, null, errorText, { parse_mode: 'HTML' });
    } else {
      await ctx.reply(errorText, { parse_mode: 'HTML' });
    }
    return null;
  }
}

// Process extracted proxy URLs
async function processProxyUrls(ctx, proxyUrls) {
  if (proxyUrls.length === 0) return;

  if (proxyUrls.length === 1) {
    // Single proxy - simple check
    const checkingMsg = await ctx.reply('🔍 Проверяю прокси...');
    await checkProxyUrl(ctx, proxyUrls[0], checkingMsg.message_id);
  } else {
    // Multiple proxies - check all with batching to avoid timeout
    const total = proxyUrls.length;
    const maxBatchSize = 10; // Max proxies per batch to avoid timeout
    
    if (total > maxBatchSize) {
      // Split into batches
      const batches = Math.ceil(total / maxBatchSize);
      const progressMsg = await ctx.reply(`🔍 Найдено прокси: ${total}\nРазбито на ${batches} партий по ${maxBatchSize}...\nНачинаю проверку...`);
      
      const allResults = [];
      
      for (let b = 0; b < batches; b++) {
        const start = b * maxBatchSize;
        const end = Math.min(start + maxBatchSize, total);
        const batch = proxyUrls.slice(start, end);
        
        await ctx.telegram.editMessageText(
          ctx.chat.id,
          progressMsg.message_id,
          null,
          `🔍 Партия ${b + 1}/${batches}\nПроверяю прокси ${start + 1}-${end} из ${total}...`
        );
        
        const batchResults = await checkProxyBatch(ctx, batch, start);
        allResults.push(...batchResults);
      }
      
      // Send final report
      sendFinalReport(ctx, progressMsg.message_id, allResults, total);
    } else {
      // Single batch
      const progressMsg = await ctx.reply(`🔍 Найдено прокси: ${total}\nПроверяю...`);
      const results = await checkProxyBatch(ctx, proxyUrls, 0);
      sendFinalReport(ctx, progressMsg.message_id, results, total);
    }
  }
}

// Check a batch of proxies
async function checkProxyBatch(ctx, proxyUrls, offset) {
  const results = [];
  const db = loadProxiesDB();

  for (let i = 0; i < proxyUrls.length; i++) {
    const url = proxyUrls[i];
    const index = offset + i + 1;

    try {
      const { server, port, secret } = parseProxyUrl(url);
      const hexSecret = normalizeSecret(secret);
      const result = await verifyProxy(server, port, hexSecret);

      results.push({
        url,
        success: result.success,
        latency: result.latency,
        error: result.error
      });

      // Add to database
      addProxyToDB(db, url, result.success, result.latency);
    } catch (err) {
      results.push({
        url,
        success: false,
        latency: null,
        error: err.message || 'Ошибка'
      });
      addProxyToDB(db, url, false);
    }
  }

  return results;
}

// Send final report
function sendFinalReport(ctx, messageId, results, total) {
  const ok = results.filter(r => r.success).length;
  const fail = results.filter(r => !r.success).length;
  
  // Separate working and non-working proxies
  const working = results.filter(r => r.success);
  const notWorking = results.filter(r => !r.success);
  
  // Format working proxies
  const workingList = working.map(r => {
    const escapedUrl = escapeHtml(r.url);
    return `• <a href="${escapedUrl}">${r.latency} мс</a>`;
  }).join('\n');
  
  // Format non-working proxies
  const failedList = notWorking.map(r => {
    const escapedUrl = escapeHtml(r.url);
    const shortError = getShortError(r.error);
    return `• <a href="${escapedUrl}">${shortError}</a>`;
  }).join('\n');
  
  // Build summary
  let summary = `<b>📊 Результаты проверки</b>\n\n`;
  summary += `<b>Всего:</b> ${total} шт.\n`;
  summary += `<b>✅ Работает:</b> ${ok}\n`;
  summary += `<b>❌ Не работает:</b> ${fail}\n\n`;
  
  if (working.length > 0) {
    summary += `<b>🟢 Рабочие прокси (${ok}):</b>\n${workingList}\n\n`;
  }
  
  if (notWorking.length > 0) {
    summary += `<b>🔴 Нерабочие прокси (${fail}):</b>\n${failedList}`;
  }
  
  // Add disclaimer
  summary += `\n\n<i>⚠️ Задержка может отличаться в зависимости от вашего оператора и местоположения</i>`;
  
  // Store working proxies for download button
  const workingUrls = working.map(r => r.url);
  if (workingUrls.length > 0) {
    storeWorkingProxies(ctx.chat.id, workingUrls);
  }
  
  // Create inline keyboard with download button
  const keyboard = working.length > 0 
    ? Markup.inlineKeyboard([
        Markup.button.callback('📥 Скачать рабочие прокси', 'download_working')
      ])
    : undefined;
  
  ctx.telegram.editMessageText(
    ctx.chat.id,
    messageId,
    null,
    summary,
    { parse_mode: 'HTML', disable_web_page_preview: true, ...keyboard }
  ).catch(() => {
    // If edit fails, send new message
    ctx.reply(summary, { parse_mode: 'HTML', disable_web_page_preview: true, ...keyboard });
  });
}

// Handle text messages (proxy URLs)
bot.on('text', async (ctx) => {
  let text = '';

  // Get text from message
  if (ctx.message.text) {
    text = ctx.message.text;
  }

  // Check caption (for messages with media)
  if (ctx.message.caption) {
    text = text ? text + '\n' + ctx.message.caption : ctx.message.caption;
  }

  if (!text) return;

  // Extract all proxy URLs from text
  const proxyUrls = extractProxyUrls(text);
  await processProxyUrls(ctx, proxyUrls);
});

// Handle forwarded messages
bot.on('forward_from', async (ctx) => {
  if (!ctx.message.text && !ctx.message.caption) return;
  
  let text = ctx.message.text || '';
  if (ctx.message.caption) {
    text = text ? text + '\n' + ctx.message.caption : ctx.message.caption;
  }
  
  const proxyUrls = extractProxyUrls(text);
  await processProxyUrls(ctx, proxyUrls);
});

// Handle forwarded messages from channels (forward_from_chat)
bot.on('forward_from_chat', async (ctx) => {
  if (!ctx.message.text && !ctx.message.caption) return;
  
  let text = ctx.message.text || '';
  if (ctx.message.caption) {
    text = text ? text + '\n' + ctx.message.caption : ctx.message.caption;
  }
  
  const proxyUrls = extractProxyUrls(text);
  await processProxyUrls(ctx, proxyUrls);
});

// Handle callback queries
bot.action('download_working', async (ctx) => {
  const workingProxies = getWorkingProxies(ctx.chat.id);

  if (!workingProxies || workingProxies.length === 0) {
    return ctx.answerCbQuery('Нет рабочих прокси для скачивания', { show_alert: true });
  }

  // Create file content
  const fileContent = workingProxies.join('\n');
  const fileName = `working_proxies_${Date.now()}.txt`;
  const filePath = path.join(__dirname, fileName);

  try {
    // Write file
    fs.writeFileSync(filePath, fileContent, 'utf-8');

    // Send file
    await ctx.replyWithDocument({
      source: fs.createReadStream(filePath),
      filename: 'working_proxies.txt'
    }, {
      caption: `📥 Рабочие прокси (${workingProxies.length} шт.)\n\n<i>Задержка может отличаться в зависимости от оператора</i>`,
      parse_mode: 'HTML'
    });

    // Clean up
    fs.unlinkSync(filePath);

    await ctx.answerCbQuery('Файл отправлен!');
  } catch (error) {
    console.error('Error sending file:', error);
    await ctx.answerCbQuery('Ошибка при создании файла', { show_alert: true });
  }
});

// Auto check settings buttons
bot.action('autocheck_enable', async (ctx) => {
  if (ADMIN_ID && ctx.from.id.toString() !== ADMIN_ID) {
    return ctx.answerCbQuery('⛔ Нет прав', { show_alert: true });
  }
  botSettings.autoCheckEnabled = true;
  saveSettings();
  await ctx.answerCbQuery('✅ Автопроверка включена');
  await ctx.editMessageText('⚙️ Настройки обновлены', { parse_mode: 'HTML' });
  // Show updated settings
  const nextCheck = botSettings.autoCheckEnabled
    ? new Date(Date.now() + botSettings.autoCheckIntervalHours * 3600000).toLocaleString('ru-RU')
    : 'Отключена';
  const settingsText = `<b>⚙️ Настройки автопроверки</b>\n\n` +
    `<b>Статус:</b> ${botSettings.autoCheckEnabled ? '✅ Включена' : '❌ Выключена'}\n` +
    `<b>Интервал:</b> ${botSettings.autoCheckIntervalHours} ч.\n` +
    `<b>Следующая проверка:</b> ${nextCheck}\n` +
    `<b>Всего проверок:</b> ${botSettings.dbCheckCount || 0}\n` +
    `<b>Очистка:</b> Каждые 2 проверки\n\n` +
    `<i>Управление кнопками ниже</i>`;
  await ctx.reply(settingsText, {
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: '▶️ Включить', callback_data: 'autocheck_enable' },
          { text: '⏸ Выключить', callback_data: 'autocheck_disable' }
        ],
        [
          { text: '➕ +6ч', callback_data: 'autocheck_interval_up' },
          { text: '➖ -6ч', callback_data: 'autocheck_interval_down' }
        ],
        [
          { text: '🔄 Проверить сейчас', callback_data: 'autocheck_run' }
        ]
      ]
    }
  });
});

bot.action('autocheck_disable', async (ctx) => {
  if (ADMIN_ID && ctx.from.id.toString() !== ADMIN_ID) {
    return ctx.answerCbQuery('⛔ Нет прав', { show_alert: true });
  }
  botSettings.autoCheckEnabled = false;
  saveSettings();
  await ctx.answerCbQuery('❌ Автопроверка выключена');
  await ctx.editMessageText('⚙️ Настройки обновлены', { parse_mode: 'HTML' });
  // Show updated settings
  const nextCheck = botSettings.autoCheckEnabled
    ? new Date(Date.now() + botSettings.autoCheckIntervalHours * 3600000).toLocaleString('ru-RU')
    : 'Отключена';
  const settingsText = `<b>⚙️ Настройки автопроверки</b>\n\n` +
    `<b>Статус:</b> ${botSettings.autoCheckEnabled ? '✅ Включена' : '❌ Выключена'}\n` +
    `<b>Интервал:</b> ${botSettings.autoCheckIntervalHours} ч.\n` +
    `<b>Следующая проверка:</b> ${nextCheck}\n` +
    `<b>Всего проверок:</b> ${botSettings.dbCheckCount || 0}\n` +
    `<b>Очистка:</b> Каждые 2 проверки\n\n` +
    `<i>Управление кнопками ниже</i>`;
  await ctx.reply(settingsText, {
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: '▶️ Включить', callback_data: 'autocheck_enable' },
          { text: '⏸ Выключить', callback_data: 'autocheck_disable' }
        ],
        [
          { text: '➕ +6ч', callback_data: 'autocheck_interval_up' },
          { text: '➖ -6ч', callback_data: 'autocheck_interval_down' }
        ],
        [
          { text: '🔄 Проверить сейчас', callback_data: 'autocheck_run' }
        ]
      ]
    }
  });
});

bot.action('autocheck_interval_up', async (ctx) => {
  if (ADMIN_ID && ctx.from.id.toString() !== ADMIN_ID) {
    return ctx.answerCbQuery('⛔ Нет прав', { show_alert: true });
  }
  botSettings.autoCheckIntervalHours = Math.min(botSettings.autoCheckIntervalHours + 6, 168);
  saveSettings();
  await ctx.answerCbQuery(`Интервал: ${botSettings.autoCheckIntervalHours} ч.`);
  await ctx.editMessageText('⚙️ Настройки обновлены', { parse_mode: 'HTML' });
  // Show updated settings
  const nextCheck = botSettings.autoCheckEnabled
    ? new Date(Date.now() + botSettings.autoCheckIntervalHours * 3600000).toLocaleString('ru-RU')
    : 'Отключена';
  const settingsText = `<b>⚙️ Настройки автопроверки</b>\n\n` +
    `<b>Статус:</b> ${botSettings.autoCheckEnabled ? '✅ Включена' : '❌ Выключена'}\n` +
    `<b>Интервал:</b> ${botSettings.autoCheckIntervalHours} ч.\n` +
    `<b>Следующая проверка:</b> ${nextCheck}\n` +
    `<b>Всего проверок:</b> ${botSettings.dbCheckCount || 0}\n` +
    `<b>Очистка:</b> Каждые 2 проверки\n\n` +
    `<i>Управление кнопками ниже</i>`;
  await ctx.reply(settingsText, {
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: '▶️ Включить', callback_data: 'autocheck_enable' },
          { text: '⏸ Выключить', callback_data: 'autocheck_disable' }
        ],
        [
          { text: '➕ +6ч', callback_data: 'autocheck_interval_up' },
          { text: '➖ -6ч', callback_data: 'autocheck_interval_down' }
        ],
        [
          { text: '🔄 Проверить сейчас', callback_data: 'autocheck_run' }
        ]
      ]
    }
  });
});

bot.action('autocheck_interval_down', async (ctx) => {
  if (ADMIN_ID && ctx.from.id.toString() !== ADMIN_ID) {
    return ctx.answerCbQuery('⛔ Нет прав', { show_alert: true });
  }
  botSettings.autoCheckIntervalHours = Math.max(botSettings.autoCheckIntervalHours - 6, 6);
  saveSettings();
  await ctx.answerCbQuery(`Интервал: ${botSettings.autoCheckIntervalHours} ч.`);
  await ctx.editMessageText('⚙️ Настройки обновлены', { parse_mode: 'HTML' });
  // Show updated settings
  const nextCheck = botSettings.autoCheckEnabled
    ? new Date(Date.now() + botSettings.autoCheckIntervalHours * 3600000).toLocaleString('ru-RU')
    : 'Отключена';
  const settingsText = `<b>⚙️ Настройки автопроверки</b>\n\n` +
    `<b>Статус:</b> ${botSettings.autoCheckEnabled ? '✅ Включена' : '❌ Выключена'}\n` +
    `<b>Интервал:</b> ${botSettings.autoCheckIntervalHours} ч.\n` +
    `<b>Следующая проверка:</b> ${nextCheck}\n` +
    `<b>Всего проверок:</b> ${botSettings.dbCheckCount || 0}\n` +
    `<b>Очистка:</b> Каждые 2 проверки\n\n` +
    `<i>Управление кнопками ниже</i>`;
  await ctx.reply(settingsText, {
    parse_mode: 'HTML',
    reply_markup: {
      inline_keyboard: [
        [
          { text: '▶️ Включить', callback_data: 'autocheck_enable' },
          { text: '⏸ Выключить', callback_data: 'autocheck_disable' }
        ],
        [
          { text: '➕ +6ч', callback_data: 'autocheck_interval_up' },
          { text: '➖ -6ч', callback_data: 'autocheck_interval_down' }
        ],
        [
          { text: '🔄 Проверить сейчас', callback_data: 'autocheck_run' }
        ]
      ]
    }
  });
});

bot.action('autocheck_run', async (ctx) => {
  if (ADMIN_ID && ctx.from.id.toString() !== ADMIN_ID) {
    return ctx.answerCbQuery('⛔ Нет прав', { show_alert: true });
  }
  await ctx.answerCbQuery('🔄 Запуск проверки...');
  await ctx.editMessageText('⚙️ Запуск проверки базы...', { parse_mode: 'HTML' });
  // Run checkdb directly
  const db = loadProxiesDB();
  const allProxies = Object.keys(db.proxies);

  if (allProxies.length === 0) {
    return ctx.reply('📭 База данных пуста');
  }

  const msg = await ctx.reply(`🔍 Проверка базы данных...\nНайдено прокси: ${allProxies.length}\n⏳ Это может занять некоторое время...`);

  const results = [];
  const total = allProxies.length;

  for (let i = 0; i < total; i++) {
    const url = allProxies[i];
    if (i % 5 === 0 || i === total - 1) {
      const progress = Math.round(((i + 1) / total) * 100);
      const progressBar = '█'.repeat(Math.floor(progress / 5)) + '░'.repeat(20 - Math.floor(progress / 5));
      try {
        await ctx.telegram.editMessageText(ctx.chat.id, msg.message_id, null, `🔍 Проверка базы данных...\n\n<code>[${progressBar}] ${progress}%</code>\nПроверено: ${i + 1} из ${total}`, { parse_mode: 'HTML' });
      } catch (e) {}
    }
    try {
      const { server, port, secret } = parseProxyUrl(url);
      const hexSecret = normalizeSecret(secret);
      const result = await verifyProxy(server, port, hexSecret);
      results.push({ url, success: result.success, latency: result.latency, error: result.error });
      addProxyToDB(db, url, result.success, result.latency);
    } catch (error) {
      results.push({ url, success: false, latency: null, error: error.message || 'Ошибка' });
      addProxyToDB(db, url, false);
    }
  }

  const ok = results.filter(r => r.success).length;
  const fail = results.filter(r => !r.success).length;
  const working = results.filter(r => r.success);

  botSettings.dbCheckCount = (botSettings.dbCheckCount || 0) + 1;
  botSettings.lastAutoCheck = new Date().toISOString();
  saveSettings();

  let summary = `<b>✅ Проверка базы завершена!</b>\n\n`;
  summary += `<b>Всего:</b> ${total} шт.\n`;
  summary += `<b>✅ Работает:</b> ${ok}\n`;
  summary += `<b>❌ Не работает:</b> ${fail}\n`;

  if (botSettings.dbCheckCount % 2 === 0) {
    summary += `\n<b>🧹 Очистка базы...</b>\n`;
    const cleanup = removeFailedProxies();
    summary += `<i>Удалено нерабочих прокси: ${cleanup.removed}</i>\n`;
  }

  summary += `\n<i>⚠️ Задержка может отличаться в зависимости от оператора</i>`;

  try {
    await ctx.telegram.editMessageText(ctx.chat.id, msg.message_id, null, summary, { parse_mode: 'HTML' });
  } catch (e) {
    await ctx.reply(summary, { parse_mode: 'HTML' });
  }

  if (working.length > 0) {
    const fileContent = working.map(r => r.url).join('\n');
    const fileName = `proxy_checked_${Date.now()}.txt`;
    const filePath = path.join(__dirname, fileName);
    fs.writeFileSync(filePath, fileContent, 'utf-8');
    await ctx.replyWithDocument({ source: fs.createReadStream(filePath), filename: 'proxy.txt' }, { caption: `📥 Рабочие прокси из базы (${working.length} шт.)` });
    fs.unlinkSync(filePath);
  }
});

// Handle errors
bot.catch((err, ctx) => {
  console.error(`Error: ${err}`);
  try {
    ctx.reply('⚠️ Произошла ошибка при обработке запроса. Попробуйте позже.');
  } catch (e) {
    // Ignore
  }
});

// Debug: log all messages
bot.use((ctx, next) => {
  if (ctx.message) {
    console.log('[MESSAGE] Type:', ctx.message.type || 'text', 'From:', ctx.from.id, 'Text:', ctx.message.text);
  }
  if (ctx.message && ctx.message.text && ctx.message.text.startsWith('/')) {
    const cmd = ctx.message.text.split(' ')[0].split('@')[0];
    console.log('[COMMAND RECEIVED]', cmd, 'from user', ctx.from.id);
  }
  return next();
});

// Start bot
async function main() {
  console.log('🤖 Запуск бота...');

  try {
    // Load settings
    loadSettings();

    // Set bot commands
    await bot.telegram.setMyCommands([
      { command: 'start', description: 'Запустить бота' },
      { command: 'help', description: 'Помощь' },
      { command: 'ping', description: 'Проверка активности' },
      { command: 'stats', description: 'Статистика базы' },
      { command: 'chkdb', description: 'Проверить базу прокси' },
      { command: 'settings', description: 'Настройки автопроверки' },
      { command: 'test', description: 'Тест бота' }
    ]);
    console.log('📋 Bot commands registered');

    // Start auto check scheduler
    if (botSettings.autoCheckEnabled) {
      startAutoCheckScheduler();
    }

    await bot.launch({
      dropPendingUpdates: true
    });

    console.log('✅ Бот запущен!');
    console.log(`Bot username: @${bot.botInfo.username}`);
    console.log('Press Ctrl-C to exit.');

    // Register commands info
    console.log('📋 Registered commands: /start, /help, /ping, /stats, /chkdb, /settings, /test');

    // Handle graceful shutdown
    process.once('SIGINT', () => bot.stop('SIGINT'));
    process.once('SIGTERM', () => bot.stop('SIGTERM'));
  } catch (error) {
    console.error('Failed to start bot:', error);
    process.exit(1);
  }
}

// Auto check scheduler
let autoCheckTimer = null;

function startAutoCheckScheduler() {
  if (autoCheckTimer) {
    clearTimeout(autoCheckTimer);
  }

  const intervalMs = botSettings.autoCheckIntervalHours * 3600000;
  const now = Date.now();
  const lastCheck = botSettings.lastAutoCheck ? new Date(botSettings.lastAutoCheck).getTime() : 0;
  const nextCheck = lastCheck + intervalMs;
  let delay = nextCheck - now;

  // If last check was more than interval ago, run now
  if (delay <= 0) {
    delay = 1000; // Run in 1 second
  }

  console.log(`[AUTO CHECK] Scheduled in ${Math.round(delay / 1000 / 60)} minutes (interval: ${botSettings.autoCheckIntervalHours}h)`);

  autoCheckTimer = setTimeout(async () => {
    console.log('[AUTO CHECK] Running scheduled check...');

    if (ADMIN_ID) {
      try {
        // Send message to admin
        await bot.telegram.sendMessage(ADMIN_ID, '🔄 <b>Запуск автоматической проверки базы...</b>', { parse_mode: 'HTML' });

        // Create mock context for chkdb command
        const mockCtx = {
          from: { id: ADMIN_ID, username: 'auto_scheduler' },
          chat: { id: ADMIN_ID },
          reply: async (text, options) => {
            await bot.telegram.sendMessage(ADMIN_ID, text, options);
          },
          telegram: {
            editMessageText: async (chatId, messageId, text, options) => {
              await bot.telegram.sendMessage(ADMIN_ID, text, options);
            }
          }
        };

        await bot.command('chkdb')(mockCtx);
      } catch (error) {
        console.error('[AUTO CHECK] Error:', error);
        await bot.telegram.sendMessage(ADMIN_ID, `❌ Ошибка автопроверки: ${error.message}`);
      }
    }

    // Schedule next check
    if (botSettings.autoCheckEnabled) {
      startAutoCheckScheduler();
    }
  }, delay);
}

main();
