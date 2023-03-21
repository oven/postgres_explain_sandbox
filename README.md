# postgres_explain_sandbox

- Intro av selv
- Intro av workshop, hvordan den gjennomføres
- Laste ned image
- Kontrollere at alt fungerer 
- Forklare kort hva EXPLAIN er

# Intro

> Hei. Mitt navn er Jørgen, og jeg jobber som konsulent for Kantega. Har jobbet her i litt over ett år. Før dette jobbet jeg på østlandet for Kongsberg Gruppen, helt til savnet etter regnet ble for stort.
>
> I disse dager jobber jeg med en dokumentdatabase som byr på sine egne fordeler og ulemper, men for det meste av karrieren min jeg brukt en eller annen form for relasjonsdatabase.
>
> Og jeg tenkte jeg ville holde denne workshopen for å kanskje gi noen et verktøy for å forbedre sin egen kunnskap om relasjonsdatabaser.

# Hvem er denne workshopen for

> Denne workshopen vil ikke lære deg SQL. Den er myntet på utviklere som kan litt SQL, og ønsker seg et verktøy til å hjelpe dem å bli bedre. Så dersom du ikke kan SQL, menuansett ønsker å gjennomføre workshopen anbefaler jeg deg å sitte deg med noen som kan SQL.

# Gjennomførelse av workshopen

> Jeg har laget et lite docker image vi skal bruke i denne workshopen, det ligger tilgjengelig på følgende GitHub repo. Så jeg vil anbefale å begynne å laste det ned. Dette imaget inneholder en Postgres database vi skal kjøre noen spørringer mot, og analysere svarene vi får tilbake.
>
> Det kommer til å være en relativt guidet workshop, med noen ganske enkle oppgaver som dere gjennomfører, for å få prøvd å utføre operasjonene selv. Jeg tenker det er bedre enn at jeg bare snakker om dem i en og en halv time.
>
> Man kan koble seg til databasen med hvilken som helst database klient, så hvis du har en du liker, så er det bare å bruke den. Om du ikke har en, så er det også tilgjengelig en web basert klient via imaget.

*DEMONSTRERE TILKOBLING*

*PGADMIN*

*VSCODE*

*INTELLIJ*

# Databasen

*Gjennomgå database*

# Hva er Postgres EXPLAIN

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
Hash Left Join  (cost=316.00..592.12 rows=9989 width=25)
  Hash Cond: (m.account_id = a.id)
  ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=15)
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

> La oss ta en kikk på noen av de vanligste nodene man vil møte på, og la oss begynne med de enkleste, og ta det derfra

## Scans

> Og da er det greit å begynne med de grunnleggende nodene som leser data. Disse vil man ofte se som løvnoder rundt om treet.
>

### Seq Scan

> Den første av dem har vi allerede sett før. Det er en kjenning av politiet. Ta gjerne å varier hva man henter fra membership, og se hvordan dette påvirker width

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

### Index scan

> Den neste scan noden vi skal gjennom er Index scan. Postgres benytter denne noden dersom den anser det som raskere å finne raden(e) man er ute etter via en index man har opprettet.
>
> Er forresten alle kjent med index'er? Kort fortalt er indexer en datastruktur laget for raskt å mappe gitte verdier til rader i databasen. Den vanligste formen for indexer er gjerne B-Tree(+). Her lager man et balansert tre over verdier i en gitt kolonne

![Forenklet illustrasjon av B-Tree index](https://i.pinimg.com/736x/32/f6/74/32f6745790e58f99188ab882afcc5d3d.jpg)


> La oss gjøre et lite eksperiment. La oss kjøre en spørring mot account tabellen og notere oss hvor lang tid den spørringen tar.
>
> Hvis vi nå spør etter raden med eposten "john.higgins@gmail.com".

```sql
explain analyze
select * from account where email = 'john.higgins@gmail.com';
```

```sql
Seq Scan on account  (cost=0.00..216.00 rows=1 width=42) (actual time=0.976..1.443 rows=1 loops=1)
  Filter: ((email)::text = 'john.higgins@gmail.com'::text)
  Rows Removed by Filter: 9999
Planning Time: 0.085 ms
Execution Time: 1.459 ms
```

> Ca. 1,5 ms er kanskje ikke så lang tid, men dette er en tabell med svært lite data i forhold til hvordan mange prod databaser ser ut. 
> 
> La oss nå opprette en index på account tabellen for epost adressene og se hvordan det påvirker kjøringen. Dette gjøres ved å kjøre

```sql
create index idx_account_email on account (email);
```

> Kjør så samme spørringen på nytt og sammenlign tidene

```sql
explain analyze
select * from account where email = 'john.higgins@gmail.com';
```

```sql
Index Scan using idx_account_email on account  (cost=0.29..8.30 rows=1 width=42) (actual time=0.033..0.034 rows=1 loops=1)
  Index Cond: ((email)::text = 'john.higgins@gmail.com'::text)
Planning Time: 0.615 ms
Execution Time: 0.052 ms
```

> 1.5 ms er etter alle standarder en rask spørring, men 0.04 ms er virkelig raskt. Det er ikke så realistisk å stå her og klage over spørringer med sensifret kjøretid i ms, men i prod kan fint få spørringer ned fra ~10 sec til noen hundre ms.

### Bitmap index scan / Bitmap heap scan

> Den siste scan noden er gjerne den noden som ser mest forvirrende ut når man møter på den i query planen. Det er kombinasjonen av Bitmap Index scan og Bitmap Heap scan. Postgres vil gjerne benytte denne dersom dataene man spør etter er indeksert, og hvis Postgres antar at noden vil returnere mange rader.

# SKRIVE MER HER


## Div

### Sort

> Denne noden er ganske selvforklarende, men det er en detalje som er grei å ha i bakhodet når man bruker den. La oss begynne med å spørre etter alle medlemskap sortert etter når de ble opprettet

```sql
explain analyze
select * from membership m order by m.created_ts;
```

```sql
Sort  (cost=913.47..938.44 rows=9989 width=31) (actual time=7.215..7.838 rows=9989 loops=1)
  Sort Key: created_ts
  Sort Method: quicksort  Memory: 1165kB
  ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.534..4.484 rows=9989 loops=1)
Planning Time: 6.550 ms
Execution Time: 8.187 ms
```

> Vi vil da se at man har fått en Seq scan, som leverer opp rader til parenten Sort. Vi kan se hva som er sort key, i vårt tilfelle created_ts, men man kan også se litt mer detaljer om utførelsen av sorteringen, som at den brukte quicksort og 1165kB minne. Sort er altså en av flere noder som ønsker å utføre arbeid i minnet.
>
> Og her begynner vi å bevege oss litt inn på databasetuning, og jeg vil gjøre det helt klart at jeg ikke ønsker at dere løper rett tilbake på jobb og endrer disse variablene i prosjektene deres uten nøye gjennomtenking.
>
> En viktig instilling i Postgres og andre databaser er hvor mye minne man tillater en operasjon å bruke. I Postgres heter denne instillingen work_mem, og er satt til 4MB ut av boksen. Med noenlunde moderne hardware er dette gjerne litt lite.
>
> Dere kan se hva den er satt til ved å kjøre show work_mem;

```sql
show work_mem;
```

> Men hva skjer om operasjonen vår trenger mer minne enn det vi tillater i work_mem?
>
> La oss simulere dette ved å redusere work_mem til 500kB

```sql
set work_mem = '500kB';
```

> Dere kan da sjekke at work_mem er oppdatert ved å kjøre show work_mem igjen.
>
> La oss deretter prøve å kjøre den sorterte spørringen vår igjen

```sql
explain analyze
select * from membership m order by m.created_ts;
```

```sql
Sort  (cost=1154.97..1179.94 rows=9989 width=31) (actual time=6.513..8.237 rows=9989 loops=1)
  Sort Key: created_ts
  Sort Method: external merge  Disk: 432kB
  ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.011..1.185 rows=9989 loops=1)
Planning Time: 0.100 ms
Execution Time: 9.127 ms
```

> Nå vil dere se at sorteringen har byttet metode fra quicksort til external merge, og nå står det Disk 432kB i stedet for Memory. Det vil si at Postgres ikke fikk plass til å utføre sorteringen i minne, og måtte dumpe dataene til disk og gjøre sorteringen der, og dette kan ha en drastisk påvirkning på hvor lang tid spørringene deres tar, så vær obs på det. Og vi vil se at det er flere nodetyper som er påvirket av work_mem for hvorvidt de må dumpe data til disk for å gjennomføre arbeidet sitt.
>
> Og kanskje noen av dere har stusset litt på at vi satt work_mem til 500kB, men nå sier sorteringen at den bare brukte 432kB. *MER HER*
>
> La oss sitte work_mem tilbake til 4MB før vi går videre

```sql
set work_mem = '4MB';
```

### Limit

> Den neste noden vi skal se på er Limit. Når man har store datasett å jobbe med er det ikke uvanlig å be om bare et begrenset utvalg av dem, da med hjelp av limit

```sql
explain analyze 
select * from membership limit 300;
```

```sql
Limit  (cost=0.00..7.50 rows=300 width=31) (actual time=0.017..0.197 rows=300 loops=1)
  ->  Seq Scan on membership  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.016..0.138 rows=300 loops=1)
Planning Time: 0.107 ms
Execution Time: 0.314 ms
```

> Her ser vi at man får en seq scan ettersom vi ikke spurte om noe spesielt. Men vi ser at seq scan'en ble stoppet etter den hadde returnert 300 rader til parent noden, til tross for at estimatet påstår at den kommer til å levere alle radene.
>
> Men hva tror resultatet blir dersom man blander sort og limit?
> Hva mange rader vil seq scannen da returnere, og kan dere tenke dere hvordan en limit vil påvirke sorteringen?

```sql
explain analyze
select * from membership order by created_ts limit 100;
```

```sql
Limit  (cost=631.66..631.91 rows=100 width=31) (actual time=4.677..4.708 rows=100 loops=1)
  ->  Sort  (cost=631.66..656.63 rows=9989 width=31) (actual time=4.675..4.688 rows=100 loops=1)
        Sort Key: created_ts
        Sort Method: top-N heapsort  Memory: 39kB
        ->  Seq Scan on membership  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.010..1.809 rows=9989 loops=1)
Planning Time: 0.185 ms
Execution Time: 4.738 ms
```

> Som dere ser leser da seq scan alle radene fra disk, selv om man bruker limit. Dette er fordi man trenger alle radene for å gjøre en sortering av dataene. Men vi ser også at sorteringemetoden er endret. Til en som tar svært lite minne. Dette er fordi den kun trenger å ta vare på de N største verdiene den har kommet over.
>
> Bonusspørsmål: Hva tror dere sort metoden vil være dersom vi sorterer med desc sort order?

```sql
explain analyze
select * from membership order by created_ts desc limit 100;
```

```sql
Limit  (cost=631.66..631.91 rows=100 width=31) (actual time=3.068..3.087 rows=100 loops=1)
  ->  Sort  (cost=631.66..656.63 rows=9989 width=31) (actual time=3.066..3.076 rows=100 loops=1)
        Sort Key: created_ts DESC
        Sort Method: top-N heapsort  Memory: 37kB
        ->  Seq Scan on membership  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.011..1.218 rows=9989 loops=1)
Planning Time: 0.089 ms
Execution Time: 3.116 ms
```

> Fortsatt top-N ;) Skal innrømme at den var litt sleip av meg.
>
> Men da er det på tide å se på den voldsomt spennende gruppen av noder som binder det hele sammen, nemlig joins.

## Visualiseringsverktøy

> Og når vi begynner å bygge trær med join, blir de fort mer komplekse. Trærne vil da få flere grener å nøste opp i. Noen ganger kan det være fint å få dem presentert i et hendig graf-format. Heldigvis finnes det et par verktøy vi kan bruke for å oppnå dette. Verktøy som vil hjelpe å få et raskt overblikk over treet, og raskt identifisere hvor flaskehalsen(e) ligger. Så på fremtidige spørringer, kan dere gjerne prøve å bruke disse verktøyene også.

Online:
- [explain.dalibo.com](https://explain.dalibo.com/)
- [explain.depesz.com](https://explain.depesz.com/)

Intellij:
- [Intellij IDEA innebygget](https://www.jetbrains.com/help/idea/visualize-execution-plan.html)
- [Dalibo plugin til Intellj](https://plugins.jetbrains.com/plugin/18804-postgres-explain-visualizer)

## Joins

### Hash Join

> Den første join formen vi skal se på er Hash join. 
>
> Og før jeg går i gang med å forklare så mye om den, vil jeg demonstrere en subtil kilde til forvirring i planene, som også sier noe om hvordan hash join fungerer. Forvirringen finner gjerne sted i planen for query nr. 2. Se om dere kan se den ved å sammenligne spørringene og hvilke noder dere får i treet.

```sql
explain analyze
select * from membership m left join organization o on m.organization_id = o.id;
```

```sql
Hash Left Join  (cost=38.58..314.78 rows=9989 width=67) (actual time=0.038..4.825 rows=9989 loops=1)
  Hash Cond: (m.organization_id = o.id)
  ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.015..1.351 rows=9989 loops=1)
  ->  Hash  (cost=22.70..22.70 rows=1270 width=36) (actual time=0.011..0.012 rows=3 loops=1)
        Buckets: 2048  Batches: 1  Memory Usage: 17kB
        ->  Seq Scan on organization o  (cost=0.00..22.70 rows=1270 width=36) (actual time=0.004..0.006 rows=3 loops=1)
Planning Time: 0.196 ms
Execution Time: 5.405 ms
```

> Og deretter spørring nr. 2


```sql
explain analyze
select * from organization o left join membership m on o.id = m.organization_id;
```

```sql
Hash Right Join  (cost=38.58..314.78 rows=9989 width=67) (actual time=0.017..2.025 rows=9989 loops=1)
  Hash Cond: (m.organization_id = o.id)
  ->  Seq Scan on membership m  (cost=0.00..249.89 rows=9989 width=31) (actual time=0.002..0.514 rows=9989 loops=1)
  ->  Hash  (cost=22.70..22.70 rows=1270 width=36) (actual time=0.010..0.011 rows=3 loops=1)
        Buckets: 2048  Batches: 1  Memory Usage: 17kB
        ->  Seq Scan on organization o  (cost=0.00..22.70 rows=1270 width=36) (actual time=0.006..0.007 rows=3 loops=1)
Planning Time: 0.076 ms
Execution Time: 2.345 ms
```

> Legger dere merke til noe litt rart med de to forrige planene. 
>
> Det er en misoppfatning å tro at dersom man bruker en left join i spørringen så vil det resultere i en Hash left join, og omvendt med right join.
>
> Faktisk er utførelsen av de to spørringene i prinsippet identiske for Postgres
>
> Hash join velger en av tabellene, som regel den med færrest rader <SJEKK DETTE> og lager hash verdier av join kriteriene man har spesifisert. Deretter går den gjennom den andre 

### Merge Join

### Nested Loop

> Nested loop er en litt spesiell join node. Den er i bruk dersom resultatet fra spørringen ikke er en filtrering av rader, men det returneres flere rader enn det var i utgangspunktet, f.eks. ved et kryssprodukt av to tabeller

```sql
explain analyze
select * from organization o cross join account a;
```

```sql
Nested Loop  (cost=0.00..158966.88 rows=12700000 width=78) (actual time=21.728..27.174 rows=30000 loops=1)
  ->  Seq Scan on account a  (cost=0.00..191.00 rows=10000 width=42) (actual time=0.291..1.421 rows=10000 loops=1)
  ->  Materialize  (cost=0.00..29.05 rows=1270 width=36) (actual time=0.000..0.000 rows=3 loops=10000)
        ->  Seq Scan on organization o  (cost=0.00..22.70 rows=1270 width=36) (actual time=0.052..0.056 rows=3 loops=1)
Planning Time: 10.676 ms
JIT:
  Functions: 3
"  Options: Inlining false, Optimization false, Expressions true, Deforming true"
"  Timing: Generation 0.236 ms, Inlining 0.000 ms, Optimization 4.842 ms, Emission 15.246 ms, Total 20.324 ms"
Execution Time: 126.592 ms
```

> Her er det for øvrig at estimatet for returnerte rader i organization er voldsomt feil, noe som i en mer kompleks spørring kunne hatt en påvirkning på hvilken plan som ble valgt
>
> Vi ser også en node som heter Materialize. Ettersom vi skal lage et kryssprodukt av alle radene, innebærer det å lese alle radene i den ene tabellen for hver av radene i den andre tabellen. Men å lese data fra disk er dyrebart. Så for å slippe å Seq scanne fra disk 10000 ganger, vil den gjøre Seq scan en gang, og skrive resultatet inn i minnet. 
>
> Man kan også se at det har kommet en nytt felt her som heter loops, her kan vi se at Seq scannen bare ble kjørt 1 gang, men utlesningen av Materialize ble kjørt 10000 ganger

### Anti-Join

# Hvordan ser dette ut i system

## Kompleks spørring - gjennomgang

1 Reverse engineere spørring

2 Fikse query mangler index

3 ???

4 Fikse lang join query

# Instillinger

## work_mem

## worker threads

### Vise parallelliserte noder, forklare loops


# Vanlige fallgruver

## Select mer enn man trenger bruker mer minne

> Feltene man nevner i select delen av spørringen trenger å holdes i minne. Dette kan ha en påvirkning når man gjør utfører operasjoner som trenger å forholde seg til work_mem. Dere kan teste og se hvordan minnebruken i Sort varierer med antallet feltet man velger i select leddet.
>
> Og jo mer minne man bruker, jo raskere møter man grensen for å måtte gjennomføre operasjonen på disk, som kan føre til en vesentlig økning i kjøretid.

## Trege Seq scans med filter

> Dette er kanskje kjent for mange, men dersom du identifiserer at en sequence scan med et filter er flaskehalsen i queriet ditt, så er det en veldig god kandidat til å opprette en index på kolonnene det filtreres på.
>
> Man vil da gå bort fra seq scan, over til en form for index scan

## Dårlig tuning

> Vi snakket litt om work_mem tidligere, og hvordan for lite minne kunne påvirke ytelsen negativt. Men det er desverre ikke bare å justere denne instillingen veldig høyt ettersom man gjerne skal betjene flere klienter samtidig. Så her må det skje en avveiing av hvor mye minne man har tilgjengelig mot hvor man koblinger man regner med å ha samtidig.
>
> Dette er bare en av flere instillinger som kan feilkonfigureres, enten ved å la den stå som default, eller ved å sette den feil. Database-tuning er en kunst som er veldig situasjonell, og vil avhenge helt av ditt spesifikke hardware og din spesifikke situasjon mtp. bruken av databasen.
>
> Noen systemer har bare titalls parallelle koblinger, mens andre har flere tusener.
>
> Av denne grunn kan ikke jeg gi noen konkrete svar på hva dere bør sette parameterne til, men jeg kan si at det finnes en god del nettbaserte konfiguratorer hvor du kan oppgi detaljer om hardware og forventet belastning, og få generert et forslag til tuning.
>
> Her er noen eksempler:

[pgconfig](https://www.pgconfig.org/)

[cybertec](https://pgconfigurator.cybertec.at/)

[postgresqlco.nf (tuning guide)](https://postgresqlco.nf/tuning-guide)

> En ulempe er at de er temmelig uenig med hverandre om hva de ideelle instillingene er, så bruk dem på eget ansvar.



## Union og view som del av spørring

### Transformasjoner kan bryte indexering

## Views kan også ende opp med å bli kjørt flere ganger i samme query, bruk materialisert CTE i stedet

## Dra mange rader gjennom en lang trestruktur

### Eksempel før og etter

## Dårlig statistikk / ingen autovacuum

> Som nevnt samler postgres statistikk over tabellene våre, men når skjer denne datainnsamlingen. Denne blir samlet inn hver gang man kjører analyze eller vacuum analyze. Analyze er lett å forveksle med explain analyze, men analyze er en frittstående funksjon man kan kjøre for å oppdatere pg_statistics.
>
> Og vacuum er en funksjon som kan kjøres for å kjøre garbage collection i databasen. Denne vacuum funksjonen kan da kjøres med en opsjon for å i tillegg oppdatere pg_statistics, som da er vacuum analyze. Populært keyword altså.
>
> Men du tenker kanskje at du kjører jo aldri analyze på databasen din. Som default kjører Postgres med en funksjon som kalles autovacuum eller The Autovacuum Daemon. En service som periodisk kjører vacuum analyze på databasen.
>
> Så dersom noen tukler med innstillingene som har med vacuuming å gjøre, så kan man fort tulle til grunnlaget for planevalueringen i samme slengen. Så man bør være forsiktig med dette.

# BONUS: Hvordan identifisere trege spørringer

> Å vite hvordan man undersøker spørringer er bare en del av regnestykket. Man må også være i stand til å finne ut hvilke spørringer som er kandidater til å forbedres. Å bruke tid på å forbedre en spørring som er en del av en daglig cron job som tar 3 sekunder, er kanskje ikke like viktig som å forbedre en 1 sekunds spørring som startes av klienten.
>
> Men man trenger uansett en oversikt over spørringene som går mot databasen. De fleste prosjekter har nok en eller annen form for innsamling av metrics som kan vise dette på en litt fin måte. Men dersom man ikke har dette, eller av en eller annen grunn ikke har tilgang til den, så kan man bruke pg_stats_statements viewet

*MÅ SLÅS PÅ*

```sql

```

## IaaS tilbyr gjerne metrics for dette, men alternativt sjekke det rett i database

*FLYTT TIL SORT NODE*

> Og nå vil jeg nevne noe som er forskjellig fra nodetype til nodetype. Noen typer kan returnere rader med en gang, som f.eks. seq scan, mens andre node typer som f.eks. Sort må vente til den har mottatt alle rader fra sine child noder før den kan begynne sitt arbeid or returnere rader. Så dere vil se for noen typer vil start-up costen være før totalkostnaden av childnoden, mens for andre typer vil den alltid være høyere.




# Avslutning

> Det var alt jeg hadde å si for denne gang. Dersom det jeg har snakket om i dag kan hjelpe noen av dere å forbedre ytelsen opp mot databasen deres, så er jeg svært fornøyd. Men nå skal dere slippe å høre mer på meg. Takk for meg, og ha en fin dag!




```sql
explain analyze
select o.*
from order_lines o
    inner join membership m on o.membership_id = m.id
    left outer join reservations r2 on o.reservation_id = r2.id
where r2.public_id = '00369c4b-991f-49be-9550-4c86aa6fe5e0'
    or m.public_id = '30b3b170-bc31-4fcb-8352-deb9e5d66db5' and (r2.id is null)
order by o.id;



explain analyze
select * from order_lines o
left join reservations r on o.reservation_id = r.id
left join membership m on o.membership_id = m.id
where (r.public_id = '00369c4b-991f-49be-9550-4c86aa6fe5e0' or (m.public_id = '30b3b170-bc31-4fcb-8352-deb9e5d66db5' and
                                                                o.reservation_id is null));


create index idx_order_line_reservation_id on order_lines(reservation_id);
create index idx_order_line_membership_id on order_lines(membership_id);

explain analyze
(select il.*
 from order_lines il
          inner join membership m
                     on il.membership_id = m.id and m.public_id = '30b3b170-bc31-4fcb-8352-deb9e5d66db5' and
                        il.reservation_id is null)
UNION ALL
(select il.*
 from order_lines il
          inner join reservations r
                     on il.reservation_id = r.id and r.public_id = '00369c4b-991f-49be-9550-4c86aa6fe5e0')
order by id;
```