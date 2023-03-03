# postgres_explain_sandbox

- Intro av selv
- Intro av workshop, hvordan den gjennomføres
- Laste ned image
- Kontrollere at alt fungerer 
- Forklare kort hva EXPLAIN er


> EXPLAIN er en innebygget funksjon i Postgres som lar deg se hvordan databasen gjennomfører spørringene dine. Dette gir deg muligheten til å både se hvor man kan gjøre forbedringer, men også til å forstå bedre hvordan relasjonsdatabaser opererer.

> La oss teste EXPLAIN funksjonen og se hvordan resultatet blir
> Vi kan f.eks. begynne med å kjøre kommandoen som står øverst i README filen

*1.1 Eksempel på bruk av explain*
```sql
explain
select a.first_name, a.last_name, m.id, m.status
from membership m
         left join account a on a.id = m.account_id
```
*Resultat:*

```sql
Sort  (cost=1255.70..1280.67 rows=9989 width=33)
  Sort Key: m.created_ts
  ->  Hash Left Join  (cost=316.00..592.12 rows=9989 width=33)
        Hash Cond: (m.account_id = a.id)
        ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=23)
        ->  Hash  (cost=191.00..191.00 rows=10000 width=18)
              ->  Seq Scan on account a  (cost=0.00..191.00 rows=10000 width=18)

```

> Det vi ser som resultat er hvordan postgres har tenkt å hente data på en måte som tilfredstiller de kravene vi satt i spørringen.
> Og dette resultatet kan tidvis se ganske fjernt ut fra spørringen vi opprinnelig skrev, og kan være ganske overveldende å tolke. Det er det vi skal prøve å lære her i dag. Vi skal gå gjennom hva alle tallene betyr, hvilke noder man vanligvis vil møte på og hvordan man ser vanlige fallgruver i spørringer.

> Men før vi begynner å snakke om dette resultatet, ønsker jeg å si litt om hvordan man ender opp med å gå fra *query* til *result*

> Når man skriver en spørring i SQL, sier man bare deklarativt hva man ønsker, uten å videre spesifisere hvordan dette skal oppnås.

> Når clienten sender et SQL statement til serveren, vil det gå gjennom pipelinen avbildet her:

![Query Pipeline](https://www.interdb.jp/pg/img/fig-3-01.png)

> Her ser man at spørringen går gjennom flere steg før den blir utført i det siste leddet i pipelinen, og det steget som er mest relevant for oss mtp. denne forelesningen, er Planner steget.

> Jeg kan si litt kort hva det er som skjer i de andre stegene.

> Parser steget mottar SQL spørringen slik du skrev den, og bryter den ned i en trestruktur som de følgende stegene kan forstå. Den gjør ingen form for validering av semantikk, eller om tabellene man refererer i det hele tatt eksisterer.

> Analyzeren er den som faktisk går Parseren i sømmene. Den validerer at det som ble laget er semantisk korrekt, at tabellene og kolonnene du spør etter finnes, og bygger opp et Query Tree hvor den legger til en del metadata rundt spørringen

> Rewriteren tar resultatet fra Analyzeren og modifiserer det i henhold til reglene som er definert i pg_rules. Nå skal jeg ikke gå for dypt inn i dette steget, men f.eks. views i Postgres er implementert gjennom å opprette en regel i pg_rules. Så når man gjør en spørring mot et view, vil rewriteren modifiserer Query Tree'et man har fått fra Analyzeren med et subquery som 'realiserer' dette viewet. 

> Og det er her vi kommer til delen av pipelinen vi er interessert i. Planneren har til oppgave å lage en eller flere planer som kan tilfrestille queriet vårt, og deretter evaluere disse planene opp mot hverandre og velge den raskeste (lavest kost). Denne planen blir så sendt videre til Executoren, som lite overraskende utfører den.
> Men hvordan vet Postgres hvor lang tid planene kommer til å ta, før den utfører dem. Noen som ønsker å gjette?

> Postgres samler statistikk om innholdet i databasen, og lagrer dette i pg_statistics tabellen. Dette er informarsjon om dataene som ligger i hver kolonne i tabellene dine. Her er det bl.a. informasjon om spredningen av verdiene, eller hvor uniforme de er, og hva de vanligste verdiene er.

Postgres samler statistikk om innholdet i databasen i tabellen pg_statistics, man kan se innholdet i den ved å kjøre


```sql
select * from pg_statistics;
```
Dette innholdet er ikke så lett å lese, så derfor har de laget et view som presenterer dataene på en litt mer menneskelig lesbar form. Dette viewet finner man ved å kjøre:


```sql
select * from pg_stats where tablename = 'membership';
```
I dette eksemplet kan man se informasjon om innholdet i membership tabellen vår.

> Ut i fra denne statisikken kan Postgres gjøre noen statistiske evalueringer over hvor effektiv en plan vil være for å hente dataene man er ute etter.
>
> Så hvis vi går tilbake til resultatet vi så tidligere

```sql
Sort  (cost=1255.70..1280.67 rows=9989 width=33)
  Sort Key: m.created_ts
  ->  Hash Left Join  (cost=316.00..592.12 rows=9989 width=33)
        Hash Cond: (m.account_id = a.id)
        ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=23)
        ->  Hash  (cost=191.00..191.00 rows=10000 width=18)
              ->  Seq Scan on account a  (cost=0.00..191.00 rows=10000 width=18)

```
> vil det da si at dette er den planen som Planneren anså som mest effektiv. Og vi kan ta å gå veldig raskt igjennom det vi ser her.
>
> Det mest iøyefallende er denne trestrukturen av "noder" her. Hvor løvnodene utføres først og returnerer data til nodene over, og så videre. Vi kommer til å gå gjennom de vanligste node-typene og forklare hvordan de fungerer senere.
>
> Deretter har vi cost elementet for noden. Dette sier noe om den statistisk beregnede kostnaden for denne noden. Det er denne beregnede totalkostnaden som brukes for å evaluere planer opp i mot hverandre. Og vi opererer her i en abstrakt kostnadsenhet. Dette er ikke en reell tidsenhet, ettersom den reelle tidskostnaden ikke er praktisk mulig for planneren å vite i forkant (påvirkes av hardware, og pg_statistics er bare en tilnærming til dataene som ligger i databasen). Men man kan si at cost er relatert til tiden som vil brukes på en node.
> 
> Men som dere ser er formatet litt snodig man har en verdi først, og deretter to prikker, før man har en ny verdi.
>
> Den første delen er det som i følge dokumentasjonen kalles Start-up kostnaden, men jeg synes dette er litt vagt. Denne verdien representerer kostnaden/tiden som frem til noden kan begynne å returnerer rader/data til parent noden, og den siste delen representerer kostnaden/tiden for at noden har returnert alle radene den skal.
>
> Det neste vi ser er rows elementet, dette sier noe om hvor mange rader postgres forventer skal vil bli returnert av en gitt node til parent noden for videre arbeid.
>
> Og til slutt har vi width, som er estimert gjennomsnittlig bytestørrelse på hver rad som returneres.
>
> Men explain som vi ser det nå er kun et estimat, og mens det kanskje har stor nytteverdi for planneren, er vi ofte mer interessert i hva som faktisk skjedde når vi utførte spørringen.
>
> Og det er her explain har noen ekstra opsjoner man kan velge. Viktigst av dem er ANALYZE (eller ANALYSE avhengig av hvor engelsk man vil være). Det gjør at postgres faktisk utfører spørringen din, og gir deg reell informasjon om utførelsen. Man får da konkrete tider i stedet for en abstrakt kostnad, og man får det korrekte antallet rader og gjennomsnittlig bytestørrelse.

```sql
explain analyze
select a.first_name, a.last_name, m.id, m.status
from membership m
         left join account a on a.id = m.account_id
order by m.created_ts;
```
> hvis vi nå ser på resultatet, vil vi kjenne igjen det meste, men vi har fått en del mer info

```sql
Sort  (cost=1255.70..1280.67 rows=9989 width=33) (actual time=16.717..17.398 rows=9989 loops=1)
  Sort Key: m.created_ts
  Sort Method: quicksort  Memory: 1165kB
  ->  Hash Left Join  (cost=316.00..592.12 rows=9989 width=33) (actual time=7.875..12.261 rows=9989 loops=1)
        Hash Cond: (m.account_id = a.id)
        ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=23) (actual time=0.007..1.158 rows=9989 loops=1)
        ->  Hash  (cost=191.00..191.00 rows=10000 width=18) (actual time=7.737..7.738 rows=10000 loops=1)
              Buckets: 16384  Batches: 1  Memory Usage: 633kB
              ->  Seq Scan on account a  (cost=0.00..191.00 rows=10000 width=18) (actual time=0.021..3.654 rows=10000 loops=1)
Planning Time: 1.423 ms
Execution Time: 19.043 ms

```

> av nye data ser man at man har fått actual time elementet (i ms), dette er inndelt på samme måte som cost elementet, med tid til man kan begynne å returnere rader og tid til alle rader er returnert
> Men man kan også se at man har fått litt mer info under en del av nodene, som f.eks. sorertingsalgoritme som ble brukt og hvor mye minne som ble brukt av denne. 
> 
> Nederst får man også oppsummering av hvor lang tid postgres brukte på å lage og evaluere alle planene og tiden den brukte på å utføre planen. Som du ser, så er det noe overhead fra rot-noden har returnert alle radene, til spørringen er ferdig utført. 

# Noder

> La oss ta en kikk på noen av de vanligste nodene man vil møte på

## Scans

> Og da er det greit å begynne med de grunnleggende nodene som leser data. Disse vil man ofte se som løvnoder rundt om treet.
>

### Seq Scan

> Den første av dem har vi allerede sett før. Det er en kjenning av politiet.

```sql
explain analyze
select * from membership;
```

```sql
Seq Scan on membership  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.010..1.164 rows=9989 loops=1)
Planning Time: 0.051 ms
Execution Time: 1.622 ms

```
> I alle eksemplene her har jeg bare formatert det slik at explain analyze kommer på sin egen linje på toppen. Du kan ha alt på en linje om du foretrekker det, men jeg gjør det som regel slik av personlig preferanse.

> Sequence scan er den mest grunnleggende av scan nodene. Den leser page for page fra databasen og returnerer radene opp til parent noden
>
> Dere kan se hva som skjer med reultatet dersom vi legger inn en where-klausul på spørringen vår

```sql
explain analyze
select * from membership where status = 'ACTIVE';
```

```sql
Seq Scan on membership  (cost=0.00..274.86 rows=8989 width=31) (actual time=0.013..2.481 rows=8989 loops=1)
  Filter: ((status)::text = 'ACTIVE'::text)
  Rows Removed by Filter: 1000
Planning Time: 0.131 ms
Execution Time: 3.176 ms

```
> Som man ser, så tar ikke noden kortere tid selv om det er færre rader den skal returnere. For den må fortsatt sekvensielt lese ut alle radene (eller pagene) fra databasen, men nå må den i tillegg gjøre en sammenligning på alle.

*FLYTT TIL SORT NODE*

> Og nå vil jeg nevne noe som er forskjellig fra nodetype til nodetype. Noen typer kan returnere rader med en gang, som f.eks. seq scan, mens andre node typer som f.eks. Sort må vente til den har mottatt alle rader fra sine child noder før den kan begynne sitt arbeid or returnere rader. Så dere vil se for noen typer vil start-up costen være før totalkostnaden av childnoden, mens for andre typer vil den alltid være høyere.