# Diagram database

![Database Diagram](https://i.ibb.co/441q5tf/database-diagram-light.png)

# Explain intro

```sql
explain
select a.first_name, a.last_name, m.id, m.status
from membership m
         left join account a on a.id = m.account_id
```


# Statistikk

Kjør

```sql
select * from pg_statistics;
```

og deretter

```sql
select * from pg_stats;
```

ta gjerne å spesisfisere et tablename også

```sql
select * from pg_stats where tablename = 'membership';
```


# Noder

## 1. Scans

    1.1 Lag en spørring som henter alle medlemskap  (og sjekk explain analyze)
<details>
<summary>Hint</summary>

```sql
select * from membership;
```
</details>

<br />

## 2. Index scan

    2.1 Opprett en index på email i account tabellen

<details>
<summary>Hint</summary>

```sql
create index idx_account_email on account (email);
```
</details>
<br />

    2.2 Hent accounten som har eposten 'john.higgins@gmail.com'
<details>
<summary>Hint</summary>

```sql
select * from account where email = 'john.higgins@gmail.com';
```
</details>
<br />

## 3. Bitmap Index Scan

I pg_stats kan man finne informasjon om korellasjonen mellom logisk plassering og fysisk plassering.

    3.1 Kjøre følgende spørringer for å se korellasjonene for kolonnen car_id i reservations, og first_name i account

```sql
select correlation from pg_stats where tablename = 'reservations' and attname = 'car_id';
select correlation from pg_stats where tablename = 'account' and attname = 'first_name';
```

Men hva betyr dette egentlig?

    3.2 For informasjon om den fysiske plasseringen til en rad kan man legge til en spesiell kolonne i selecten som heter CTID
        Kjøre de følgende spørringene for å se den logiske sorteringen opp mot den fysiske plasseringen

```sql
select ctid, * from reservations order by car_id;
select ctid, * from reservations order by car_id desc;


select ctid, * from account order by first_name;
select ctid, * from account order by first_name desc;
```

3.3 Opprett en index på car_id i reservations tabellen

3.4 Hent alle reservasjoner som er kjørt av bilen med id 7 (og sjekk explain analyze)


Her skal vi se forskjellen på å hente data mellom noe som har høy og lav korrelasjon

    3.5 Opprett en index på first_name i account tabellen

<details>
<summary>Hint</summary>

```sql
create index idx_account_first_name on account(first_name);
```
</details>
<br />

    3.6 Hent alle accounts hvor fornavnet er 'John' (og sjekk explain analyze)

<details>
<summary>Hint</summary>

```sql
select * from account where first_name = 'John';
```
</details>
<br />


## 4. Sort

    4.1 Hent alle medlemskap sortert etter når de ble opprettet, tidligst først
    
Hint

    4.2 Sjekk work_mem instillingen i databasen

Hint

    4.3 Sett work_mem lavere enn minneforbruket til Sort noden fra 4.1

Hint

    4.4 Kjøre spørring 4.1 på nytt

Hint

    4.5 Sett work_mem tilbake til 4MB


## 5. Limit

    5.1 Hent 300 medlemskap, usortert

Hint

    5.2 Hent 300 medlemskap, sortert

Hint


## 6. HashAggregate / GroupAggregate

    6.1 Hent en oversikt over hvor mange ganger hvert fornavn blir brukt i accounts

Hint

    6.2 Hent en liste over distinkte fornavn i databasen

Hint

    6.3 Hent en liste over alle eposter som tilhører hvert fornavn

## 7. Hash Join

    7.1 Hent medlemskap joined med tilhørende organisasjon

Hint

    7.2 Snu rekkefølgen på tabellene i join spørringen

Hint

    7.3 Gjør en inner join mellom medlemskap og ordrelinjer for aktive medlemskap

Hint

    7.3 Undersøk planen visuelt

    7.4 Endre work_mem og se hvordan det påvirker resultatet


## 8. Nested loop



## 9. Oppgaver

    9.1 Prøv å komme frem til hva den opprinnelige spørringen var for de følgende planene


```sql
Sort  (cost=209.92..214.92 rows=2000 width=58)
  Sort Key: cla.start_time
  ->  Hash Right Join  (cost=64.00..100.26 rows=2000 width=58)
        Hash Cond: (cla.car_id = c.id)
        ->  Seq Scan on car_location_assignments cla  (cost=0.00..31.00 rows=2000 width=16)
        ->  Hash  (cost=39.00..39.00 rows=2000 width=42)
              ->  Seq Scan on car c  (cost=0.00..39.00 rows=2000 width=42)
```


```sql
Sort  (cost=1544352.44..1556341.97 rows=4795815 width=152)
  Sort Key: m.id
  ->  Hash Left Join  (cost=56981.00..290924.56 rows=4795815 width=152)
        Hash Cond: (o.membership_id = m.id)
        ->  Hash Left Join  (cost=56660.00..278009.21 rows=4795815 width=105)
              Hash Cond: (o.reservation_id = r.id)
              ->  Seq Scan on order_lines o  (cost=0.00..102394.15 rows=4795815 width=53)
              ->  Hash  (cost=27714.00..27714.00 rows=1300000 width=52)
                    ->  Seq Scan on reservations r  (cost=0.00..27714.00 rows=1300000 width=52)
        ->  Hash  (cost=196.00..196.00 rows=10000 width=47)
              ->  Seq Scan on membership m  (cost=0.00..196.00 rows=10000 width=47)
JIT:
  Functions: 17
"  Options: Inlining true, Optimization true, Expressions true, Deforming true"
```


```sql
Hash Join  (cost=595.69..830.19 rows=100 width=103)
  Hash Cond: (m.account_id = account.id)
  ->  Seq Scan on membership m  (cost=0.00..196.00 rows=10000 width=47)
  ->  Hash  (cost=594.44..594.44 rows=100 width=56)
        ->  Limit  (cost=593.19..593.44 rows=100 width=56)
              ->  Sort  (cost=593.19..618.19 rows=10000 width=56)
                    Sort Key: account.first_name
                    ->  Seq Scan on account  (cost=0.00..211.00 rows=10000 width=56)
```

    9.2 Se om du kan identifisere potensielle forbedringer i de følgende spørringene

```sql
Spørring med manglende index
```

```sql
create index idx_account_email on account(email);

select * from order_lines o
inner join reservations r on o.reservation_id = r.id
inner join membership m on r.membership_id = m.id
inner join account a on m.account_id = a.id
where lower(a.email) = 'helen_rolfson37@yahoo.com';
```


```sql
select * from order_lines o
left join reservations r on o.reservation_id = r.id
left join membership m on o.membership_id = m.id
where (r.public_id = 'cd883c8a-3e12-4de7-a6d5-2fb4fcd71d60' or (m.public_id = '4c94e5c8-5820-46cc-be23-eb1e55ad2f01' and
                                                                o.reservation_id is null));
```
