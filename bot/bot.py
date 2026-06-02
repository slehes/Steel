import asyncio
import base64
import json
import logging
import sqlite3
from datetime import datetime, date
from pathlib import Path

from aiogram import Bot, Dispatcher, F, Router
from aiogram.enums import ParseMode
from aiogram.filters import CommandStart, Command
from aiogram.types import (
    Message, CallbackQuery,
    InlineKeyboardMarkup, InlineKeyboardButton,
    ReplyKeyboardMarkup, KeyboardButton,
)
from aiogram.client.default import DefaultBotProperties
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

BOT_TOKEN = "8112616068:AAGR9fsSClI7CViqXNZTFDHk-o8ijWpE-iw"
DB_PATH   = Path(__file__).parent / "steel.db"

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


def pe(emoji_id: str, fallback: str) -> str:
    return f'<tg-emoji emoji-id="{emoji_id}">{fallback}</tg-emoji>'

FIRE  = pe("5089479191414440704", "🔥")
BOLT  = pe("5172425562634847208", "⚡️")
CHECK = pe("5870633910337015697", "✅")
CROSS = pe("5870657884844462243", "❌")
GRAPH = pe("5870930636742595124", "📊")
CLOCK = pe("5983150113483134607", "⏰")
STAR  = pe("6041731551845159060", "🎉")
BOTIE = pe("6030400221232501136", "🤖")
UP    = pe("5963103826075456248", "⬆")
INFO  = pe("6028435952299413210", "ℹ")
LOCK  = pe("6037249452824072506", "🔒")
PERSON= pe("5870994129244131212", "👤")
GREEN = pe("5416081784641168838", "🟢")


def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    with db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            chat_id    INTEGER PRIMARY KEY,
            username   TEXT DEFAULT '',
            first_name TEXT DEFAULT '',
            created_at TEXT DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS habits (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id       INTEGER,
            title         TEXT,
            category      TEXT,
            streak_start  REAL DEFAULT 0,
            best_streak   INTEGER DEFAULT 0,
            relapse_count INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS tasks (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id INTEGER,
            title   TEXT,
            amount  INTEGER DEFAULT 0,
            unit    TEXT DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS user_settings (
            chat_id     INTEGER PRIMARY KEY,
            streak_days INTEGER DEFAULT 0,
            user_name   TEXT    DEFAULT 'Воин'
        );
        """)

def is_new(chat_id: int) -> bool:
    with db() as c:
        return c.execute("SELECT 1 FROM users WHERE chat_id=?", (chat_id,)).fetchone() is None

def upsert_user(chat_id: int, username: str, first_name: str):
    with db() as c:
        c.execute(
            "INSERT OR IGNORE INTO users (chat_id, username, first_name) VALUES (?,?,?)",
            (chat_id, username, first_name)
        )

def save_sync(chat_id: int, payload: dict):
    with db() as c:
        c.execute(
            "INSERT OR REPLACE INTO user_settings (chat_id, streak_days, user_name) VALUES (?,?,?)",
            (chat_id, payload.get("streakDays", 0), payload.get("userName", "Воин"))
        )
        c.execute("DELETE FROM habits WHERE chat_id=?", (chat_id,))
        for h in payload.get("habits", []):
            c.execute(
                "INSERT INTO habits (chat_id,title,category,streak_start,best_streak,relapse_count) VALUES (?,?,?,?,?,?)",
                (chat_id, h.get("title",""), h.get("categoryRaw","bad"),
                 h.get("streakStart", 0), h.get("bestStreak", 0), h.get("relapseCount", 0))
            )
        c.execute("DELETE FROM tasks WHERE chat_id=?", (chat_id,))
        for t in payload.get("tasks", []):
            c.execute(
                "INSERT INTO tasks (chat_id,title,amount,unit) VALUES (?,?,?,?)",
                (chat_id, t.get("title",""), t.get("amount",0), t.get("unit",""))
            )

def get_data(chat_id: int) -> dict | None:
    with db() as c:
        s = c.execute("SELECT * FROM user_settings WHERE chat_id=?", (chat_id,)).fetchone()
        if not s:
            return None
        habits = c.execute("SELECT * FROM habits WHERE chat_id=?", (chat_id,)).fetchall()
        tasks  = c.execute("SELECT * FROM tasks  WHERE chat_id=?", (chat_id,)).fetchall()
        return {
            "streakDays": s["streak_days"],
            "userName":   s["user_name"],
            "habits":     [dict(h) for h in habits],
            "tasks":      [dict(t) for t in tasks],
        }

def all_chat_ids() -> list[int]:
    with db() as c:
        return [r["chat_id"] for r in c.execute("SELECT chat_id FROM users").fetchall()]


def ru_days(n: int) -> str:
    last2, last1 = n % 100, n % 10
    if 11 <= last2 <= 19: return f"{n} дней"
    if last1 == 1:        return f"{n} день"
    if 2 <= last1 <= 4:   return f"{n} дня"
    return f"{n} дней"

def clean_days(ts: float) -> int:
    return max(0, (date.today() - date.fromtimestamp(ts)).days)

def build_report(data: dict, time_label: str) -> str:
    streak = data["streakDays"]
    user   = data.get("userName", "Воин")
    habits = data["habits"]
    tasks  = data["tasks"]
    today  = datetime.now().strftime("%d.%m.%Y")

    bad  = [h for h in habits if h["category"] == "bad"]
    good = [h for h in habits if h["category"] == "good"]

    lines = [
        f"{BOLT} <b>Steel — Отчёт {time_label}</b>",
        f"<i>{today} · {user}</i>",
        "",
        f"{FIRE} <b>Серия: {ru_days(streak)}</b>",
    ]

    if tasks:
        lines += ["", f"{BOLT} <b>Зарядка:</b>"]
        for t in tasks:
            lines.append(f"  {CHECK} {t['title']}/{t['amount']} {t['unit']}"
                         f"  {BOLT}{t.get('amount',0)}  {FIRE}{t.get('amount',0)}")

    if bad:
        lines += ["", f"{CROSS} <b>Вредные привычки:</b>"]
        for h in bad:
            d = clean_days(h["streak_start"])
            lines.append(f"  {CHECK} {h['title']}  {BOLT}{ru_days(d)}  {FIRE}{ru_days(d)}")

    if good:
        lines += ["", f"{CHECK} <b>Полезные привычки:</b>"]
        for h in good:
            d = clean_days(h["streak_start"])
            lines.append(f"  {CHECK} {h['title']}  {BOLT}{ru_days(d)}  {FIRE}{ru_days(d)}")

    lines += ["", f"{GRAPH} <b>Так держать!</b>"]
    return "\n".join(lines)


def main_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [
                KeyboardButton(text="Отчёт",         icon_custom_emoji_id="5870930636742595124"),
                KeyboardButton(text="Синхронизация", icon_custom_emoji_id="5963103826075456248"),
            ],
            [KeyboardButton(text="Помощь", icon_custom_emoji_id="6028435952299413210")],
        ],
        resize_keyboard=True
    )

def sync_help_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[[
        InlineKeyboardButton(
            text="Как синхронизировать",
            callback_data="sync_help",
            icon_custom_emoji_id="6028435952299413210"
        )
    ]])


router = Router()

@router.message(CommandStart())
async def cmd_start(msg: Message):
    new_user = is_new(msg.chat.id)
    upsert_user(msg.chat.id, msg.from_user.username or "", msg.from_user.first_name or "")

    if new_user:
        text = (
            f"{STAR} <b>Добро пожаловать в Steel!</b>\n\n"
            f"{PERSON} Привет, <b>{msg.from_user.first_name}</b>!\n\n"
            f"{FIRE} Я буду отправлять тебе отчёты по привычкам "
            f"каждый день в <b>00:00</b> и <b>12:00</b> по МСК.\n\n"
            f"{BOLT} <b>Как начать:</b>\n"
            f"1. Открой приложение <b>Steel</b>\n"
            f"2. Настройки → <b>Резервная копия</b>\n"
            f"3. Нажми «<b>Скопировать резервную копию</b>»\n"
            f"4. Отправь боту:\n"
            f"<code>/sync [вставь строку здесь]</code>\n\n"
            f"{GREEN} После синхронизации отчёты будут с твоими реальными данными.\n\n"
            f"{LOCK} Данные хранятся только на сервере бота."
        )
    else:
        text = (
            f"{FIRE} <b>С возвращением!</b>\n\n"
            f"{BOLT} Используй кнопки ниже для управления."
        )

    await msg.answer(text, parse_mode=ParseMode.HTML, reply_markup=main_kb())


@router.message(F.text == "Отчёт")
@router.message(Command("report"))
async def cmd_report(msg: Message):
    upsert_user(msg.chat.id, msg.from_user.username or "", msg.from_user.first_name or "")
    data = get_data(msg.chat.id)
    if not data:
        await msg.answer(
            f"{CROSS} <b>Данные не синхронизированы.</b>\n\n"
            f"Отправь <code>/sync [строка из приложения]</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=sync_help_kb()
        )
        return
    await msg.answer(build_report(data, datetime.now().strftime("%H:%M")), parse_mode=ParseMode.HTML)


@router.message(F.text == "Синхронизация")
async def sync_prompt(msg: Message):
    await msg.answer(
        f"{UP} <b>Синхронизация</b>\n\n"
        f"1. Открой <b>Steel → Настройки → Резервная копия</b>\n"
        f"2. Нажми <b>«Скопировать резервную копию»</b>\n"
        f"3. Отправь мне:\n\n"
        f"<code>/sync [вставь строку]</code>",
        parse_mode=ParseMode.HTML
    )


@router.message(F.text == "Помощь")
@router.message(Command("help"))
async def cmd_help(msg: Message):
    await msg.answer(
        f"{BOTIE} <b>Steel Bot — Команды</b>\n\n"
        f"{BOLT} /start — перезапустить бота\n"
        f"{GRAPH} /report — отчёт прямо сейчас\n"
        f"{UP} /sync [строка] — синхронизировать данные\n\n"
        f"{CLOCK} Отчёты автоматически в <b>00:00</b> и <b>12:00</b> по МСК\n\n"
        f"{INFO} <b>Синхронизация:</b>\n"
        f"Steel → Настройки → Резервная копия → Скопировать → /sync [строка]",
        parse_mode=ParseMode.HTML
    )


@router.message(Command("sync"))
async def cmd_sync(msg: Message):
    parts = (msg.text or "").split(maxsplit=1)
    if len(parts) < 2 or not parts[1].strip():
        await msg.answer(
            f"{INFO} Укажите строку:\n<code>/sync [строка из приложения]</code>",
            parse_mode=ParseMode.HTML
        )
        return

    backup_str = parts[1].strip()
    try:
        payload = json.loads(base64.b64decode(backup_str))
    except Exception:
        await msg.answer(
            f"{CROSS} <b>Неверный формат строки.</b>\n\n"
            f"Получи актуальную строку в приложении:\n"
            f"<b>Настройки → Резервная копия → Скопировать</b>",
            parse_mode=ParseMode.HTML
        )
        return

    upsert_user(msg.chat.id, msg.from_user.username or "", msg.from_user.first_name or "")
    save_sync(msg.chat.id, payload)

    await msg.answer(
        f"{CHECK} <b>Синхронизация успешна!</b>\n\n"
        f"{FIRE} Серия: <b>{ru_days(payload.get('streakDays', 0))}</b>\n"
        f"{BOLT} Привычек: <b>{len(payload.get('habits', []))}</b>\n\n"
        f"{CLOCK} Отчёты будут приходить в <b>00:00</b> и <b>12:00</b>",
        parse_mode=ParseMode.HTML
    )


@router.callback_query(F.data == "sync_help")
async def cb_sync_help(cb: CallbackQuery):
    await cb.message.edit_text(
        f"{UP} <b>Как синхронизировать:</b>\n\n"
        f"1. Открой <b>Steel</b>\n"
        f"2. Настройки → <b>Резервная копия</b>\n"
        f"3. <b>Скопировать резервную копию</b>\n"
        f"4. Отправь боту:\n"
        f"<code>/sync [вставь строку]</code>",
        parse_mode=ParseMode.HTML
    )
    await cb.answer()


async def send_reports(bot: Bot, time_label: str):
    for chat_id in all_chat_ids():
        data = get_data(chat_id)
        if not data:
            continue
        try:
            await bot.send_message(chat_id, build_report(data, time_label), parse_mode=ParseMode.HTML)
        except Exception as e:
            logging.warning(f"Report failed {chat_id}: {e}")


async def main():
    init_db()
    bot = Bot(token=BOT_TOKEN, default=DefaultBotProperties(parse_mode=ParseMode.HTML))
    dp  = Dispatcher()
    dp.include_router(router)

    scheduler = AsyncIOScheduler(timezone="Europe/Moscow")
    scheduler.add_job(send_reports, CronTrigger(hour=0,  minute=0,  timezone="Europe/Moscow"), args=[bot, "00:00"], id="midnight")
    scheduler.add_job(send_reports, CronTrigger(hour=12, minute=0,  timezone="Europe/Moscow"), args=[bot, "12:00"], id="noon")
    scheduler.start()

    await dp.start_polling(bot, skip_updates=True)


if __name__ == "__main__":
    asyncio.run(main())
