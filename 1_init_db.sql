CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE organization (
    id serial primary key,
    name varchar
);

CREATE TABLE account (
    id serial primary key,
    public_id uuid,
    first_name varchar,
    last_name varchar,
    email varchar
);

CREATE TABLE membership_type (
    id serial primary key,
    name varchar
);

CREATE TABLE membership (
    id serial primary key,
    public_id uuid,
    account_id integer not null references account (id),
    membership_type_id integer not null references membership_type (id),
    organization_id integer not null references organization (id),
    status varchar,
    created_ts timestamp
);

CREATE TABLE product (
    id serial primary key,
    public_id uuid,
    name varchar,
    msrp numeric(10,2)
);

CREATE TABLE location (
    id serial primary key,
    name varchar
);


CREATE TABLE model (
    id serial primary key,
    public_id uuid,
    name varchar,
    manufacturer varchar,
    seats integer,
    doors integer,
    fuel_type varchar
);

CREATE TABLE car (
    id serial primary key,
    public_id uuid,
    license_number varchar,
    model_id integer not null references model (id),
    color varchar,
    owner_organization integer not null references organization (id)
);

CREATE TABLE extra_equipment (
    id serial primary key,
    name varchar
);

CREATE TABLE car_location_assignments (
    car_id integer not null references car (id),
    location_id integer references location (id),
    start_time timestamp,
    PRIMARY KEY(car_id, location_id)
);

CREATE TABLE car_extra_equipment_assignments (
    car_id integer not null references car (id),
    extra_equipment_id integer not null references extra_equipment (id),
    PRIMARY KEY(car_id, extra_equipment_id)
);

CREATE TABLE reservations (
    id serial primary key,
    public_id uuid,
    membership_id integer not null references membership (id),
    car_id integer not null references car (id),
    planned_start timestamp,
    planned_end timestamp,
    state varchar
);

CREATE TABLE trips (
    id serial primary key,
    reservation_id integer not null references reservations (id),
    start_ts timestamp,
    end_ts timestamp,
    driven_km integer
);

CREATE TABLE invoice (
    id serial primary key,
    public_id uuid,
    membership_id integer references membership (id),
    status varchar
);

CREATE TABLE order_lines (
    id serial primary key,
    public_id uuid,
    membership_id integer references membership (id),
    reservation_id integer references reservations (id),
    product_id integer not null references product (id),
    count integer,
    total numeric(10,2),
    invoice_id integer references invoice (id),
    created timestamp
);



