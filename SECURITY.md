# Sicurezza d'uso

Questo progetto permette di azionare fisicamente un cancello tramite rete locale e servizi cloud.  
Per questo motivo è importante proteggere sia le credenziali sia l'accesso ai dispositivi Hikvision.

## Credenziali

Non salvare password, App Secret o altre credenziali direttamente negli script.

In particolare, evita di inserire valori reali dentro:

```text
*.ps1
*.py
*.json
*.env
README.md
```

La configurazione H24 fornita con il progetto salva le credenziali fuori dalla cartella principale, nel file:

```text
C:\Home-Domotica\Config\hikvision-sinric.dpapi.json
```

Le credenziali vengono protette tramite Windows DPAPI (`LocalMachine`) e il file è accessibile solo a `SYSTEM` e agli amministratori locali.

## Rete locale

Il monitor Hikvision del setup di riferimento utilizza:

```text
192.168.1.84:8000
```

La porta SDK `8000` dovrebbe essere raggiungibile solo dalla rete locale o da host fidati.

Non è consigliato esporre direttamente su Internet:

- porta SDK Hikvision `8000`;
- interfaccia HTTP del videocitofono;
- altri servizi di gestione del sistema Hikvision.

Se serve accesso remoto, è preferibile utilizzare una VPN o un altro accesso remoto protetto alla rete domestica.

## Account Hikvision

Se il dispositivo e il firmware lo consentono, è preferibile usare un account dedicato al bridge con i soli permessi necessari.

Evitare, quando possibile, di usare un account amministratore per servizi automatici H24.

## Server Windows

Il computer che esegue il bridge deve essere considerato parte dell'impianto domotico.

È consigliato:

- mantenere Windows aggiornato;
- mantenere Python aggiornato;
- mantenere iVMS-4200 / HCNetSDK aggiornati;
- limitare l'accesso amministrativo al server;
- usare una password Windows robusta;
- lasciare attivi Microsoft Defender e il firewall di Windows.

## Controllo vocale e servizi cloud

Il comando Google Home passa attraverso servizi cloud esterni:

```text
Google Home
    ↓
Sinric Pro
    ↓
Bridge locale
    ↓
Hikvision
```

Se Internet, Google Home o Sinric Pro non sono disponibili, il comando vocale potrebbe non funzionare.

Per questo motivo è consigliato mantenere anche un metodo locale o manuale per l'apertura del cancello.

## Aperture accidentali

Il bridge include due protezioni:

- cooldown tra due comandi consecutivi;
- ignorare temporaneamente un eventuale stato `ON` ripristinato da Sinric Pro all'avvio.

Nel setup di riferimento i valori predefiniti sono:

```text
HIKVISION_GATE_COOLDOWN=10
SINRICPRO_STARTUP_IGNORE=8
```

Questi valori possono essere aumentati se si desidera ridurre ulteriormente il rischio di comandi duplicati.

## Log

Il log H24 viene scritto in:

```text
C:\Home-Domotica\Logs\sinric-bridge.log
```

Il log dovrebbe contenere solo informazioni operative.

Se viene modificato il progetto o vengono aggiunti nuovi debug, evitare di stampare password, token o App Secret nei log.

## Se una credenziale viene compromessa

Se si sospetta che una password o una chiave Sinric Pro sia stata esposta:

1. cambiare la password Hikvision interessata;
2. rigenerare App Key / App Secret Sinric Pro se necessario;
3. rieseguire `configure-hikvision-h24.ps1`;
4. verificare che il bridge torni operativo;
5. controllare i log per eventuali accessi o comandi anomali.

## Sicurezza fisica

Questo software invia un comando reale di apertura.

Prima di usarlo in automazioni più complesse, verificare che:

- il cancello disponga delle protezioni meccaniche ed elettriche previste;
- fotocellule e sistemi di sicurezza funzionino correttamente;
- l'apertura automatica non possa creare situazioni pericolose.

Il bridge non sostituisce i sistemi di sicurezza integrati nell'automazione del cancello.
