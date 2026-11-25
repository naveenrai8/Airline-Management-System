-- Flight Tables schema (PostgreSQL dialect)
-- Derived from docs/Flight-Tables.md
--
-- Tables are created in dependency order so that foreign keys resolve:
--   base entities  -> airport, airline, airplane_layout
--   derived        -> route, airport_terminal, terminal_gates
--   flight domain  -> flight, flight_instance, flight_running_status

-- ---------------------------------------------------------------------------
-- 2. Airport
--    Minimal information of an airport. Primary key is the ICAO code.
-- ---------------------------------------------------------------------------
CREATE TABLE airport
(
    id         CHAR(4) PRIMARY KEY,          -- ICAO code (e.g. VOBL)
    short_name VARCHAR(16)  NOT NULL UNIQUE, -- secondary key
    name       VARCHAR(128) NOT NULL,
    city       VARCHAR(64)  NOT NULL,
    state      VARCHAR(64),
    country    VARCHAR(64)  NOT NULL
);

-- ---------------------------------------------------------------------------
-- 5. Airline
-- ---------------------------------------------------------------------------
CREATE TABLE airline
(
    id         VARCHAR(16) PRIMARY KEY, -- airline id (e.g. 6E)
    name       VARCHAR(128) NOT NULL,
    short_name VARCHAR(32)              -- optional
);

-- ---------------------------------------------------------------------------
-- 9. Airplane Layout
--    Seat layout of an airplane.
-- ---------------------------------------------------------------------------
CREATE TABLE airplane_layout
(
    id              VARCHAR(32) PRIMARY KEY,
    number_of_seats INTEGER NOT NULL CHECK (number_of_seats > 0)
);

-- ---------------------------------------------------------------------------
-- 1. Route
--    Route between two airports; id is the two ICAO codes joined with a dot
--    (e.g. 'VOBL.VIDP', 9 chars: 4 + '.' + 4).
-- ---------------------------------------------------------------------------
CREATE TABLE route
(
    source_airport_icao CHAR(4) NOT NULL REFERENCES airport (id),
    dest_airport_icao   CHAR(4) NOT NULL REFERENCES airport (id),
    primary key (source_airport_icao, dest_airport_icao)
);

-- ---------------------------------------------------------------------------
-- 3. Airport Terminal
--    Terminals per airport; id is (airport ICAO + terminal id).
--    airport_name is intentionally not stored here - it is redundant and
--    derivable via a join to airport.name through airport_icao.
-- ---------------------------------------------------------------------------
CREATE TABLE airport_terminal
(
    airport_icao  CHAR(4)    NOT NULL REFERENCES airport (id),
    terminal_id   VARCHAR(8) NOT NULL, -- e.g. T1, T2, T3
    terminal_name VARCHAR(64),
    primary key (airport_icao, terminal_id)
);

-- ---------------------------------------------------------------------------
-- 4. Terminal Gates
--    Gates per terminal per airport; id is (airport ICAO + terminal id + gate id).
-- ---------------------------------------------------------------------------
CREATE TABLE terminal_gates
(
    airport_icao CHAR(4)    NOT NULL,
    terminal_id  VARCHAR(8) NOT NULL, -- e.g. T1, T2, T3
    gate_id      VARCHAR(8) NOT NULL, -- e.g. 1A, 2B, 3
    FOREIGN KEY (airport_icao, terminal_id)
        REFERENCES airport_terminal (airport_icao, terminal_id),
    primary key (airport_icao, terminal_id, gate_id)
);

-- ---------------------------------------------------------------------------
-- 6. Flight
--    General flight information (not a running instance).
--    Note: docs/Flight-Tables.md lists "date" in the id but only a "week day"
--    column; the recurring/general flight is keyed on week_day here.
-- ---------------------------------------------------------------------------
CREATE TABLE flight
(
    flight_id    VARCHAR(16)    NOT NULL, -- e.g. 6E125
    route_id     VARCHAR(9)     NOT NULL,
    week_day     SMALLINT       NOT NULL CHECK (week_day BETWEEN 1 AND 7),
    start_time   TIME           NOT NULL,
    duration INTERVAL NOT NULL,           -- end time = start time + duration
    airline_id   VARCHAR(16)    NOT NULL REFERENCES airline (id),
    minimum_fare NUMERIC(10, 2) NOT NULL CHECK (minimum_fare >= 0),
    primary key (week_day, route_id, flight_id)
);

-- ---------------------------------------------------------------------------
-- 7. Flight Instance
--    A flight scheduled on a specific date between a source and destination.
-- ---------------------------------------------------------------------------
CREATE TABLE flight_instance
(
    flight_id          VARCHAR(16)    NOT NULL,                   -- e.g. 6E125
    route_id           VARCHAR(9)     NOT NULL,
    flight_date        DATE           NOT NULL,
    start_time         TIME           NOT NULL,
    duration INTERVAL NOT NULL,                                   -- end time = start time + duration
    airline_id         VARCHAR(16)    NOT NULL REFERENCES airline (id),
    airplane_layout_id VARCHAR(32)    NOT NULL REFERENCES airplane_layout (id),
    total_seats        INTEGER        NOT NULL CHECK (total_seats >= 0),
    fare               NUMERIC(10, 2) NOT NULL CHECK (fare >= 0), -- constant fare per passenger
    primary key (flight_date, route_id, flight_id)
);

-- ---------------------------------------------------------------------------
-- 8. Flight Running Status
--    Live running status of a flight between a source and destination.
-- ---------------------------------------------------------------------------

CREATE TABLE flight_running_status
(
    flight_id             VARCHAR(16)  NOT NULL, -- e.g. 6E125
    source                CHAR(4)      NOT NULL REFERENCES airport (id),
    destination           CHAR(4)      NOT NULL REFERENCES airport (id),
    flight_date           DATE         NOT NULL,
    start_time            TIME         NOT NULL,
    duration INTERVAL NOT NULL,                  -- end time = start time + duration
    airline_id            VARCHAR(16)  NOT NULL REFERENCES airline (id),
    expected_start_time   TIME,
    expected_arrival_time TIME,
    running_status        VARCHAR(100) NOT NULL,
    primary key (flight_date, flight_id, source, destination)
);

CREATE INDEX idx_frs_date_status ON flight_running_status (flight_date, running_status);
