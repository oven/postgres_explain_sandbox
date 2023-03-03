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
> Det mest iøyefallende er denne trestrukturen av "noder" her. Hvor løvnodene utføres først og returnerer data til nodene over, og så videre.
>
> Deretter har vi cost elementet for noden. Dette sier noe om den statistisk beregnede kostnaden for denne noden. Det er denne beregnede totalkostnaden som brukes for å evaluere planer opp i mot hverandre. Og vi opererer her i en abstrakt kostnadsenhet. Dette er ikke en reell tidsenhet, ettersom den reelle tidskostnaden ikke er praktisk mulig for planneren å vite i forkant (påvirkes av hardware, og pg_statistics er bare en tilnærming til dataene som ligger i databasen). Men man kan si at cost er relatert til tiden som vil brukes på en node.
> 
> Men som dere ser er formatet litt snodig man har en verdi først, og deretter to prikker, før man har en ny verdi.
>
> Den første delen representerer kostnaden/tiden som frem til noden kan begynne å returnerer rader/data til parent noden, og den siste delen representerer kostnaden/tiden for at noden har returnert alle radene den skal.
>
> 