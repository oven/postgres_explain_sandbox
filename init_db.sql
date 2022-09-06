CREATE TABLE some_table (
    id serial primary key,
    name varchar
);



INSERT INTO some_table (name)
SELECT 'some' || generate_series from generate_series(0,10);