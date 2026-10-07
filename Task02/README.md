# Task02. ETL: генерация и загрузка данных в SQLite

Каталог содержит утилиту, которая по исходным текстовым файлам (скопированным из `dataset`) генерирует SQL-скрипт `db_init.sql` и загружает его в базу данных SQLite `movies_rating.db`.

## Требования к окружению

Чтобы скрипт `db_init.bat` отработал корректно, на компьютере должны быть установлены:

- **Python 3** (проверено на 3.12) — доступен из командной строки по команде `python3`.
- **SQLite3** — утилита командной строки `sqlite3` должна быть доступна в `PATH` (см. установку в `Git_instruction.md` / `task01.md`).
- **bash** — для запуска самого `db_init.bat` (на Linux/macOS есть по умолчанию; на Windows — через Git Bash или WSL).

## Как запустить

```bash
chmod +x db_init.bat   # один раз, если бит исполняемости ещё не выставлен
./db_init.bat
```

Скрипт выполнит две вещи:
1. Запустит `python3 make_db_init.py`, который прочитает `movies.csv`, `users.txt`, `ratings.csv`, `tags.csv` и сгенерирует `db_init.sql` (с инструкциями `DROP TABLE`, `CREATE TABLE` и `INSERT INTO`).
2. Выполнит `sqlite3 movies_rating.db < db_init.sql` — применит скрипт к базе `movies_rating.db`. Если файл базы или таблицы в ней уже существуют, они будут пересозданы с нуля.

## Структура базы данных movies_rating.db

### Таблица movies
| Поле   | Тип           | Описание                                   |
|--------|---------------|---------------------------------------------|
| id     | INTEGER (PK)  | movieId из movies.csv                       |
| title  | VARCHAR       | Название фильма без года выпуска             |
| year   | INTEGER       | Год выпуска, вынесен из названия             |
| genres | VARCHAR       | Жанры, разделённые `\|`                       |

### Таблица users
| Поле           | Тип          | Описание                        |
|----------------|--------------|-----------------------------------|
| id             | INTEGER (PK) | userId из users.txt               |
| name           | VARCHAR      | Имя пользователя                  |
| email          | VARCHAR      | Электронная почта                 |
| gender         | VARCHAR      | Пол                                |
| register_date  | DATE         | Дата регистрации (ГГГГ-ММ-ДД)     |
| occupation     | VARCHAR      | Род занятий                        |

### Таблица ratings
| Поле      | Тип                 | Описание                              |
|-----------|---------------------|------------------------------------------|
| id        | INTEGER (PK, AUTOINCREMENT) | Суррогатный ключ                |
| user_id   | INTEGER             | Ссылка на users.id                       |
| movie_id  | INTEGER             | Ссылка на movies.id                      |
| rating    | REAL                | Оценка (0.5–5.0)                          |
| timestamp | INTEGER             | Unix time оценки                          |

### Таблица tags
| Поле      | Тип                 | Описание                              |
|-----------|---------------------|------------------------------------------|
| id        | INTEGER (PK, AUTOINCREMENT) | Суррогатный ключ                |
| user_id   | INTEGER             | Ссылка на users.id                       |
| movie_id  | INTEGER             | Ссылка на movies.id                      |
| tag       | VARCHAR             | Текст тега                                |
| timestamp | INTEGER             | Unix time простановки тега                |

Размеры текстовых полей (`VARCHAR(N)`) вычисляются автоматически утилитой `make_db_init.py` исходя из максимальной длины значения в исходных данных.
