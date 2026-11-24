PRAGMA foreign_keys = ON;

-- ============================================================================
-- База данных: Автоматизация работы станции технического обслуживания (СТО)
-- СУБД: SQLite 3
-- ============================================================================

-- Удаление таблиц в обратном порядке зависимостей (для повторной инициализации)
DROP TABLE IF EXISTS completed_work_items;
DROP TABLE IF EXISTS completed_works;
DROP TABLE IF EXISTS appointment_services;
DROP TABLE IF EXISTS appointments;
DROP TABLE IF EXISTS services;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS work_schedules;
DROP TABLE IF EXISTS employees;

-- 1. Сотрудники (мастера и персонал СТО)
-- При увольнении запись не удаляется: выставляются dismissal_date и is_active = 0.
CREATE TABLE employees (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name       TEXT    NOT NULL CHECK (length(trim(full_name)) > 0),
    phone           TEXT    NOT NULL UNIQUE,
    position        TEXT    NOT NULL DEFAULT 'Автомеханик',
    commission_rate REAL    NOT NULL DEFAULT 35.0 CHECK (commission_rate >= 0.0 AND commission_rate <= 100.0),
    hire_date       TEXT    NOT NULL DEFAULT (date('now')),
    dismissal_date  TEXT             DEFAULT NULL,
    is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),
    CHECK ((is_active = 1 AND dismissal_date IS NULL) OR (is_active = 0 AND dismissal_date IS NOT NULL))
);

-- 2. Индивидуальный график работы мастеров
CREATE TABLE work_schedules (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1: Пн .. 7: Вс
    start_time  TEXT    NOT NULL, -- Формат HH:MM
    end_time    TEXT    NOT NULL, -- Формат HH:MM
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    UNIQUE (employee_id, day_of_week),
    CHECK (end_time > start_time)
);

-- 3. Клиенты СТО
CREATE TABLE clients (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL CHECK (length(trim(full_name)) > 0),
    phone     TEXT NOT NULL UNIQUE,
    car_brand TEXT NOT NULL,
    car_plate TEXT NOT NULL UNIQUE
);

-- 4. Справочник предоставляемых услуг
CREATE TABLE services (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT    NOT NULL UNIQUE,
    category     TEXT    NOT NULL DEFAULT 'Общее ТО',
    duration_min INTEGER NOT NULL CHECK (duration_min > 0),
    price        REAL    NOT NULL CHECK (price >= 0.0),
    is_active    INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
);

-- 5. Предварительная запись к мастеру
CREATE TABLE appointments (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id        INTEGER NOT NULL,
    employee_id      INTEGER NOT NULL,
    appointment_date TEXT    NOT NULL, -- Формат YYYY-MM-DD
    start_time       TEXT    NOT NULL, -- Формат HH:MM
    end_time         TEXT    NOT NULL, -- Формат HH:MM
    status           TEXT    NOT NULL DEFAULT 'scheduled'
                     CHECK (status IN ('scheduled', 'completed', 'cancelled', 'no_show')),
    notes            TEXT    NOT NULL DEFAULT '',
    created_at       TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (client_id)   REFERENCES clients(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (end_time > start_time)
);

-- 6. Услуги в предварительной записи (связь M:N)
CREATE TABLE appointment_services (
    appointment_id INTEGER NOT NULL,
    service_id     INTEGER NOT NULL,
    quantity       INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (appointment_id, service_id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (service_id)     REFERENCES services(id)     ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 7. Фактически выполненные работы мастерами
CREATE TABLE completed_works (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    appointment_id INTEGER UNIQUE DEFAULT NULL, -- NULL, если обращение без предварительной записи
    client_id      INTEGER NOT NULL,
    employee_id    INTEGER NOT NULL,
    work_date      TEXT    NOT NULL DEFAULT (date('now')),
    total_amount   REAL    NOT NULL DEFAULT 0.0 CHECK (total_amount >= 0.0),
    comment        TEXT    NOT NULL DEFAULT '',
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (client_id)      REFERENCES clients(id)      ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (employee_id)    REFERENCES employees(id)    ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 8. Детализация фактически выполненных работ (связь M:N с фиксацией цены и длительности)
CREATE TABLE completed_work_items (
    work_id             INTEGER NOT NULL,
    service_id          INTEGER NOT NULL,
    quantity            INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    actual_price        REAL    NOT NULL CHECK (actual_price >= 0.0),
    actual_duration_min INTEGER NOT NULL CHECK (actual_duration_min > 0),
    PRIMARY KEY (work_id, service_id),
    FOREIGN KEY (work_id)    REFERENCES completed_works(id) ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id)        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Индексы для ускорения поиска занятости, расчета зарплаты и отчетов
CREATE INDEX idx_appointments_emp_date ON appointments(employee_id, appointment_date);
CREATE INDEX idx_completed_works_emp_date ON completed_works(employee_id, work_date);

-- ============================================================================
-- Заполнение тестовыми данными
-- ============================================================================

-- Сотрудники (4 работающих, 1 уволенный для демонстрации сохранения истории)
INSERT INTO employees (id, full_name, phone, position, commission_rate, hire_date, dismissal_date, is_active) VALUES
(1, 'Иванов Алексей Сергеевич',    '+7-900-111-22-33', 'Автомеханик',    40.0, '2023-03-15', NULL,         1),
(2, 'Петров Дмитрий Викторович',   '+7-900-222-33-44', 'Автоэлектрик',   45.0, '2023-06-01', NULL,         1),
(3, 'Сидоров Михаил Андреевич',    '+7-900-333-44-55', 'Диагност',       42.5, '2024-01-10', NULL,         1),
(4, 'Козлов Сергей Николаевич',    '+7-900-444-55-66', 'Шиномонтажник',  35.0, '2024-05-20', NULL,         1),
(5, 'Волков Игорь Павлович',       '+7-900-555-66-77', 'Автомеханик',    38.0, '2022-11-01', '2026-10-15', 0);

-- Индивидуальные графики работы
INSERT INTO work_schedules (employee_id, day_of_week, start_time, end_time) VALUES
-- Иванов (Пн-Пт 09:00-18:00)
(1, 1, '09:00', '18:00'), (1, 2, '09:00', '18:00'), (1, 3, '09:00', '18:00'),
(1, 4, '09:00', '18:00'), (1, 5, '09:00', '18:00'),
-- Петров (Вт-Сб 10:00-19:00)
(2, 2, '10:00', '19:00'), (2, 3, '10:00', '19:00'), (2, 4, '10:00', '19:00'),
(2, 5, '10:00', '19:00'), (2, 6, '10:00', '16:00'),
-- Сидоров (Пн, Ср, Пт 08:00-20:00)
(3, 1, '08:00', '20:00'), (3, 3, '08:00', '20:00'), (3, 5, '08:00', '20:00'),
-- Козлов (Чт-Вс 09:00-18:00)
(4, 4, '09:00', '18:00'), (4, 5, '09:00', '18:00'), (4, 6, '10:00', '17:00'), (4, 7, '10:00', '16:00');

-- Клиенты
INSERT INTO clients (id, full_name, phone, car_brand, car_plate) VALUES
(1, 'Смирнов Олег Владимирович',  '+7-911-100-01-01', 'Toyota Camry',     'А123ВС77'),
(2, 'Кузнецова Анна Игоревна',    '+7-911-200-02-02', 'Kia Rio',          'В456ЕК77'),
(3, 'Новиков Павел Дмитриевич',   '+7-911-300-03-03', 'Volkswagen Polo',  'Е789МН77'),
(4, 'Морозова Елена Сергеевна',   '+7-911-400-04-04', 'Hyundai Solaris',  'К321ОР77'),
(5, 'Федоров Артем Алексеевич',   '+7-911-500-05-05', 'Skoda Octavia',    'М654ТУ77');

-- Справочник услуг
INSERT INTO services (id, name, category, duration_min, price, is_active) VALUES
(1, 'Замена масла и масляного фильтра', 'Общее ТО',      45,  1800.00, 1),
(2, 'Компьютерная диагностика ЭБУ',     'Диагностика',   30,  1500.00, 1),
(3, 'Замена передних тормозных колодок','Ходовая часть', 60,  2500.00, 1),
(4, 'Развал-схождение (2 оси)',         'Ходовая часть', 60,  3200.00, 1),
(5, 'Поиск и устранение утечки тока',   'Электрика',     90,  3500.00, 1),
(6, 'Сезонная переобувка R16 (4 колеса)','Шиномонтаж',   40,  2400.00, 1),
(7, 'Замена свечей зажигания (4 шт.)',  'Общее ТО',      40,  1600.00, 1);

-- Предварительная запись
INSERT INTO appointments (id, client_id, employee_id, appointment_date, start_time, end_time, status, notes) VALUES
(1, 1, 1, '2026-10-10', '09:00', '10:45', 'completed', 'Плановое ТО'),
(2, 2, 5, '2026-10-12', '11:00', '12:00', 'completed', 'Скрип при торможении (уволенный позже мастер)'),
(3, 3, 2, '2026-11-18', '10:00', '11:30', 'completed', 'Разряжается АКБ за ночь'),
(4, 4, 3, '2026-11-20', '14:00', '14:30', 'completed', 'Горит Check Engine'),
(5, 5, 4, '2026-11-24', '10:00', '10:40', 'scheduled', 'Сезонная замена резины'),
(6, 1, 1, '2026-11-25', '11:00', '12:00', 'scheduled', 'Проверка ходовой'),
(7, 2, 3, '2026-11-25', '15:00', '15:30', 'cancelled', 'Клиент перенес визит');

-- Услуги в предварительной записи
INSERT INTO appointment_services (appointment_id, service_id, quantity) VALUES
(1, 1, 1), (1, 3, 1),
(2, 3, 1),
(3, 5, 1),
(4, 2, 1),
(5, 6, 1),
(6, 4, 1),
(7, 2, 1);

-- Фактически выполненные работы (включая работу уволенного мастера Волкова и заказ без записи)
INSERT INTO completed_works (id, appointment_id, client_id, employee_id, work_date, total_amount, comment) VALUES
(1, 1,    1, 1, '2026-10-10', 4300.00, 'Выполнено по записи в полном объеме'),
(2, 2,    2, 5, '2026-10-12', 2500.00, 'Замена колодок выполнена мастером Волковым'),
(3, 3,    3, 2, '2026-11-18', 3500.00, 'Устранена утечка в цепи магнитолы'),
(4, 4,    4, 3, '2026-11-20', 1500.00, 'Сброс и диагностика ошибки датчика кислорода'),
(5, NULL, 5, 1, '2026-11-21', 3400.00, 'Обращение без предварительной записи');

-- Детализация фактически выполненных работ
INSERT INTO completed_work_items (work_id, service_id, quantity, actual_price, actual_duration_min) VALUES
(1, 1, 1, 1800.00, 45),
(1, 3, 1, 2500.00, 60),
(2, 3, 1, 2500.00, 55),
(3, 5, 1, 3500.00, 85),
(4, 2, 1, 1500.00, 30),
(5, 1, 1, 1800.00, 45),
(5, 7, 1, 1600.00, 40);