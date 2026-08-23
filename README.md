# tg-web

Автоинсталлятор WEB-прокси для Telegram с красивыми сайтами.

## Быстрый старт

### Через curl

```bash
curl -sO https://raw.githubusercontent.com/prominbro/tg-web/main/install.sh
sudo bash install.sh
```

### Через wget

```bash
wget https://raw.githubusercontent.com/prominbro/tg-web/main/install.sh
sudo bash install.sh
```

### Через git clone

```bash
git clone https://github.com/prominbro/tg-web.git
cd tg-web
sudo bash install.sh
```

## Что ставится

- **WEB-прокси для Telegram** — релей tproxy-server + официальный MTProxy
- **Красивый сайт** — 10 вариантов на выбор в стиле «стекло» (glassmorphism)
- **HTTPS/SSL** — автоматический сертификат Let's Encrypt
- **Nginx** — реверс-прокси с поддержкой WebSocket
- **Systemd** — все сервисы автозапускаются

## Сайты

| # | Сайт | Описание |
|---|------|----------|
| 1 | ВКонтакте | История соцсети ВКонтакте |
| 2 | Telegram | История мессенджера Telegram |
| 3 | Instagram | ⚠️ Meta — экстремистская организация в РФ |
| 4 | YouTube | История видеохостинга YouTube |
| 5 | Одноклассники | История соцсети Одноклассники |
| 6 | О кошках | Факты о кошках |
| 7 | О собаках | Факты о собаках |
| 8 | О белых песцах | Факты о белых песцах |
| 9 | О музыке | История музыки |
| 10 | О программировании | История программирования |

## Режимы транспорта

| Режим | Описание | Скорость | Заметность |
|-------|----------|----------|------------|
| `https` | Сериализованный POST + long poll | Средняя | Низкая (по умолчанию) |
| `https-lanes` | Изолированные потоки по HTTP | Высокая | Низкая |
| `websocket` | Один WS на все потоки | Очень высокая | Средняя |
| `ws-lanes` | Один WS на каждый поток | Максимальная | Средняя |

## Требования

- **OS:** Debian 12+ / Ubuntu 22.04+
- **Arch:** x86_64
- **Root:** да
- **Порты:** 80, 443 открыты
- **DNS:** A-запись домена → IP сервера
- **Время:** 5-10 минут на установку (скрипт собирает Go и MTProxy)

## Удаление

### Через curl

```bash
curl -sO https://raw.githubusercontent.com/prominbro/tg-web/main/uninstall.sh
sudo bash uninstall.sh
```

### Через wget

```bash
wget https://raw.githubusercontent.com/prominbro/tg-web/main/uninstall.sh
sudo bash uninstall.sh
```

### Через git clone

```bash
cd tg-web
sudo bash uninstall.sh
```

## После установки

### Клиент (Telegram Desktop)

```
Хост:   ваш-домен.com
Secret: <секрет из вывода скрипта>
```

Или по ссылке:
```
https://t.me/webproxy?server=ваш-домен.com&secret=<секрет>
```

### Метрики трафика

```bash
curl http://127.0.0.1:8081/metrics | grep bytes
```

### Обновление сайта

```bash
cp -r ~/tg-web/sites/имя-сайта/. /srv/tproxy-site/
systemctl restart tproxy-server
```

### Логи

```bash
journalctl -u tproxy-server -f
journalctl -u mtproxy -f
```

### Перезапуск всех сервисов

```bash
systemctl restart tproxy-firewall mtproxy tproxy-server
```

## Структура проекта

```
tg-web/
├── install.sh              # Интерактивный автоинсталлятор
├── uninstall.sh            # Полное удаление
├── README.md
└── sites/
    ├── _shared/            # Общий CSS/JS/favicon
    ├── vk/                 # ВКонтакте
    ├── telegram/           # Telegram
    ├── instagram/          # Instagram
    ├── youtube/            # YouTube
    ├── odnoklassniki/      # Одноклассники
    ├── cats/               # Кошки
    ├── dogs/               # Собаки
    ├── foxes/              # Белые песцы
    ├── music/              # Музыка
    └── coding/             # Программирование
```
## Добавить свой сайт

1. Создай директорию `sites/твой-сайт/`
2. Добавь `index.html`, `about.html`, `privacy.html`, `404.html`
3. Скопируй `sites/_shared/styles.css` и `script.js`
4. Добавь логотип в `sites/твой-сайт/assets/`
5. Обнови `install.sh` — добавь номер в меню

## Лицензия

MIT
