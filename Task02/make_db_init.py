#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_db_init.py

Утилита ETL (Extract, Transform, Load) для лабораторной работы №2.
Читает исходные данные из текстовых файлов (movies.csv, ratings.csv,
tags.csv, users.txt), лежащих рядом со скриптом, и генерирует SQL-скрипт
db_init.sql, который при выполнении утилитой sqlite3 пересоздаёт базу
данных movies_rating.db и заполняет её этими данными.

Запуск:
    python3 make_db_init.py
"""

import csv
import os
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MOVIES_FILE = os.path.join(BASE_DIR, "movies.csv")
RATINGS_FILE = os.path.join(BASE_DIR, "ratings.csv")
TAGS_FILE = os.path.join(BASE_DIR, "tags.csv")
USERS_FILE = os.path.join(BASE_DIR, "users.txt")
OUTPUT_FILE = os.path.join(BASE_DIR, "db_init.sql")

TITLE_YEAR_RE = re.compile(r"^(.*)\s\((\d{4})\)\s*$")


def sql_escape(value):
    """Экранирует одинарные кавычки для безопасной вставки в SQL-литерал."""
    return value.replace("'", "''")


def sql_str(value):
    """Оборачивает строку в SQL-литерал, NULL для пустых значений."""
    if value is None or value == "":
        return "NULL"
    return "'" + sql_escape(value) + "'"


def sql_num(value):
    """Числовой литерал SQL, NULL для пустых значений."""
    if value is None or value == "":
        return "NULL"
    return value


def read_movies():
    movies = []
    with open(MOVIES_FILE, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            raw_title = row["title"].strip()
            match = TITLE_YEAR_RE.match(raw_title)
            if match:
                title, year = match.group(1).strip(), match.group(2)
            else:
                title, year = raw_title, None
            movies.append({
                "id": row["movieId"],
                "title": title,
                "year": year,
                "genres": row["genres"],
            })
    return movies


def read_users():
    users = []
    with open(USERS_FILE, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n").rstrip("\r")
            if not line:
                continue
            user_id, name, email, gender, register_date, occupation = line.split("|")
            users.append({
                "id": user_id,
                "name": name,
                "email": email,
                "gender": gender,
                "register_date": register_date,
                "occupation": occupation,
            })
    return users


def read_ratings():
    ratings = []
    with open(RATINGS_FILE, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            ratings.append({
                "user_id": row["userId"],
                "movie_id": row["movieId"],
                "rating": row["rating"],
                "timestamp": row["timestamp"],
            })
    return ratings


def read_tags():
    tags = []
    with open(TAGS_FILE, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            tags.append({
                "user_id": row["userId"],
                "movie_id": row["movieId"],
                "tag": row["tag"],
                "timestamp": row["timestamp"],
            })
    return tags


def max_len(values):
    return max((len(v) for v in values if v), default=1)


def build_sql(movies, users, ratings, tags):
    title_len = max_len([m["title"] for m in movies])
    genres_len = max_len([m["genres"] for m in movies])
    name_len = max_len([u["name"] for u in users])
    email_len = max_len([u["email"] for u in users])
    gender_len = max_len([u["gender"] for u in users])
    occupation_len = max_len([u["occupation"] for u in users])
    tag_len = max_len([t["tag"] for t in tags])

    lines = []
    lines.append("PRAGMA foreign_keys = OFF;")
    lines.append("")

    # --- удаление старых таблиц, если они есть ---
    for table in ("tags", "ratings", "movies", "users"):
        lines.append(f"DROP TABLE IF EXISTS {table};")
    lines.append("")

    # --- создание таблиц ---
    lines.append(f"""CREATE TABLE movies (
    id INTEGER PRIMARY KEY,
    title VARCHAR({title_len}) NOT NULL,
    year INTEGER,
    genres VARCHAR({genres_len})
);""")
    lines.append("")

    lines.append(f"""CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name VARCHAR({name_len}) NOT NULL,
    email VARCHAR({email_len}),
    gender VARCHAR({gender_len}),
    register_date DATE,
    occupation VARCHAR({occupation_len})
);""")
    lines.append("")

    lines.append("""CREATE TABLE ratings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    movie_id INTEGER NOT NULL REFERENCES movies(id),
    rating REAL NOT NULL,
    timestamp INTEGER NOT NULL
);""")
    lines.append("")

    lines.append(f"""CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    movie_id INTEGER NOT NULL REFERENCES movies(id),
    tag VARCHAR({tag_len}) NOT NULL,
    timestamp INTEGER NOT NULL
);""")
    lines.append("")

    # --- вставка данных ---
    lines.append("BEGIN TRANSACTION;")
    lines.append("")

    for m in movies:
        lines.append(
            f"INSERT INTO movies (id, title, year, genres) VALUES "
            f"({sql_num(m['id'])}, {sql_str(m['title'])}, {sql_num(m['year'])}, {sql_str(m['genres'])});"
        )
    lines.append("")

    for u in users:
        lines.append(
            f"INSERT INTO users (id, name, email, gender, register_date, occupation) VALUES "
            f"({sql_num(u['id'])}, {sql_str(u['name'])}, {sql_str(u['email'])}, "
            f"{sql_str(u['gender'])}, {sql_str(u['register_date'])}, {sql_str(u['occupation'])});"
        )
    lines.append("")

    for r in ratings:
        lines.append(
            f"INSERT INTO ratings (user_id, movie_id, rating, timestamp) VALUES "
            f"({sql_num(r['user_id'])}, {sql_num(r['movie_id'])}, {sql_num(r['rating'])}, {sql_num(r['timestamp'])});"
        )
    lines.append("")

    for t in tags:
        lines.append(
            f"INSERT INTO tags (user_id, movie_id, tag, timestamp) VALUES "
            f"({sql_num(t['user_id'])}, {sql_num(t['movie_id'])}, {sql_str(t['tag'])}, {sql_num(t['timestamp'])});"
        )
    lines.append("")

    lines.append("COMMIT;")
    lines.append("")

    return "\n".join(lines)


def main():
    movies = read_movies()
    users = read_users()
    ratings = read_ratings()
    tags = read_tags()

    sql = build_sql(movies, users, ratings, tags)

    with open(OUTPUT_FILE, "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)

    print(f"Сгенерирован {OUTPUT_FILE}: "
          f"{len(movies)} фильмов, {len(users)} пользователей, "
          f"{len(ratings)} оценок, {len(tags)} тегов.")


if __name__ == "__main__":
    main()
