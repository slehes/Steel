<div align="center">

<img src="icon.png" alt="Steel Banner" width="100%">

# ⚔️ Steel

**Дисциплина — это свобода**

[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-15%2B-147EFB?style=for-the-badge&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-UI%20Framework-0D1117?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Groq AI](https://img.shields.io/badge/AI-Groq%20Llama%203.3-FF6F00?style=for-the-badge&logo=robot&logoColor=white)](https://groq.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 🛡️ О проекте

**Steel** — это iOS-приложение для самодисциплины, трекинга привычек и ежедневных задач со встроенным ИИ-тренером. Приложение помогает формировать полезные привычки, отслеживать прогресс и не сдаваться на пути к лучшей версии себя.

Вдохновлён философией: дисциплина — не ограничение, а путь к свободе. Steel даёт инструменты для ежедневной работы над собой — от простых чеклистов до интеллектуального тренера, который не даёт расслабиться.

---

## ✨ Ключевые возможности

### 📋 Ежедневные задачи
- Создание задач с количеством и единицей измерения (50 отжиманий, 10 км бега, 2 л воды)
- Отслеживание выполнения с автосбросом на следующий день
- Статистика и подсчёт общего числа выполненных задач

### 🛑 Трекер привычек
- Отслеживание «чистых дней» (streak) для каждой привычки
- Фиксация срывов с автоматическим сбросом streak
- История лучшей серии и количество срывов

### 🤖 ИИ-тренер (Groq + Llama 3.3 70B)
- Чат-бот в стиле жёсткого тренера с чёрным юмором
- Голосовое управление приложением через команды:
  - Добавление/удаление задач и привычек
  - Установка напоминаний
  - Составление тренировочных планов
  - Смена фона приложения
  - Парсинг веб-сайтов для поиска информации

### 🎨 Кастомизация
- Персональные фоны — фото и видео
- Настройка яркости и затемнения фона
- Тёмная тема по умолчанию

### 🔔 Уведомления
- Локальные push-уведомления в заданные часы
- Автоматическое расписание напоминаний
- Напоминания о невыполненных задачах

### 📱 Виджеты и Live Activity
- Home Screen виджет с прогрессом дня
- Live Activity на экране блокировки
- Динамический Island (Dynamic Island) для отслеживания в реальном времени

---

## 📸 Скриншоты

> *Скриншоты будут добавлены после сборки*

---

## 🏗 Архитектура

```
Steel/
├── 📱 App
│   ├── AppDelegate.swift          # Запуск, Keychain, уведомления
│   ├── SceneDelegate.swift        # Сцены и навигация
│   └── MainTabBarController.swift # Таб-бар навигации
├── 🎨 UI
│   ├── TodayViewController.swift  # Экран «Сегодня»
│   ├── HabitsViewController.swift # Экран привычек
│   ├── PlanViewController.swift   # Тренировочные планы
│   ├── ProfileViewController.swift# Профиль пользователя
│   ├── AIChatViewController.swift # Чат с ИИ-тренером
│   ├── AddTaskViewController.swift# Добавление задачи
│   ├── AddHabitViewController.swift# Добавление привычки
│   └── BackgroundPicker.swift    # Выбор фона
├── 🧠 AI
│   ├── GrogAI.swift              # Groq API интеграция
│   ├── CommandExecutor.swift     # Исполнение AI-команд
│   └── WebAgent.swift            # Веб-парсинг
├── 💾 Data
│   ├── Models.swift              # SwiftData модели
│   ├── DataManager.swift         # Управление данными
│   ├── SharedStore.swift         # Общее хранилище
│   └── KeychainHelper.swift      # Keychain доступ
├── 🔧 Services
│   ├── NotificationManager.swift # Уведомления
│   ├── BackgroundManager.swift   # Управление фонами
│   └── MediaProcessor.swift      # Обработка медиа
├── 🧩 Components
│   ├── HabitCell.swift           # Ячейка привычки
│   ├── TaskCell.swift            # Ячейка задачи
│   ├── ChatBubbleCell.swift      # Пузырь чата
│   └── ProgressHeaderView.swift  # Заголовок прогресса
└── 📦 SteelWidget
    ├── SteelWidget.swift         # Home Screen виджет
    ├── SteelLiveActivity.swift   # Live Activity
    └── SteelWidgetBundle.swift   # Bundle виджетов
```

---

## 🚀 Установка

### Требования
- **Xcode 15+**
- **iOS 17+**
- **Swift 5.9+**
- **Groq API Key** (для ИИ-тренера)

### Шаги

1. **Клонируйте репозиторий:**
   ```bash
   git clone https://github.com/slehes/Steel.git
   cd Steel
   ```

2. **Откройте проект в Xcode:**
   ```bash
   open ios-steel/Steel.xcodeproj
   ```

3. **Настройте API-ключ Groq:**
   - При первом запуске приложение запросит API-ключ
   - Получите ключ на [console.groq.com](https://console.groq.com)

4. **Соберите и запустите:**
   - Выберите target `Steel` и ваш iOS-устройство или симулятор
   - Нажмите `⌘R` для запуска

---

## 🤖 AI-команды

ИИ-тренер понимает следующие команды в чате:

| Команда | Описание | Пример |
|---------|----------|--------|
| `ADD_TASK` | Добавить задачу | «Добавь 50 отжиманий» |
| `REMOVE_TASK` | Удалить задачу | «Убери отжимания» |
| `ADD_HABIT` | Добавить привычку | «Добавь отказ от сахара» |
| `REMOVE_HABIT` | Удалить привычку | «Удали привычку Сахар» |
| `SET_REMINDER` | Установить напоминания | «Напоминай в 9, 19 и 22» |
| `BUILD_PLAN` | Составить план | «Составь план тренировок» |
| `CHANGE_BACKGROUND` | Сменить фон | «Поменяй фон» |
| `SCRAPE_SITE` | Найти на сайте | «Найди на example.com информацию о...» |

---

## 🛠 Технологии

| Технология | Назначение |
|-----------|-----------|
| **Swift / SwiftUI** | Основной язык и UI-фреймворк |
| **SwiftData** | Персистентное хранение данных |
| **UIKit** | Часть интерфейсов |
| **Groq API** | ИИ-тренер (Llama 3.3 70B) |
| **WidgetKit** | Home Screen виджеты |
| **ActivityKit** | Live Activity / Dynamic Island |
| **Keychain** | Безопасное хранение API-ключей |
| **UserNotifications** | Локальные push-уведомления |
| **AVFoundation** | Видеофоны |

---

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. Подробности в файле [LICENSE](LICENSE).

---

<div align="center">

**⚔️ Дисциплина — это свобода ⚔️**

</div>
