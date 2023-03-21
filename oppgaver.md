# Diagram database



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

## Scans

Lag en spørring som henter alle medlemskap.
<details>
<summary>Hint</summary>

```sql
select * from membership;
```
</details>


## Index scan

Lage en index på email i account tabellen
<details>
<summary>Hint</summary>

```sql
create index idx_account_email on account (email);
```
</details>