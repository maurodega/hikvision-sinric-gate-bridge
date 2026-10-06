# Hikvision Gate Bridge — Google Home + Sinric Pro + HCNetSDK

Bridge per **Windows 10/11 x64** che permette di aprire un cancello Hikvision con Google Home usando **Sinric Pro**, Python e l'HCNetSDK installato insieme a iVMS-4200.

Il progetto può funzionare in due modalità:

- **interattiva**, utile per il primo test;
- **H24**, con avvio automatico di Windows anche senza login dell'utente.

> Il progetto invia un comando reale di apertura. Usalo esclusivamente su un impianto che possiedi o amministri.

---

## Indice

- [Come funziona](#come-funziona)
- [Configurazione di riferimento](#configurazione-di-riferimento)
- [Requisiti](#requisiti)
- [Installazione](#installazione)
- [1. Verifica dei prerequisiti](#1-verifica-dei-prerequisiti)
- [2. Test Hikvision locale](#2-test-hikvision-locale)
- [3. Configurazione Sinric Pro](#3-configurazione-sinric-pro)
- [4. Configurazione Google Home](#4-configurazione-google-home)
- [5. Avvio interattivo del bridge](#5-avvio-interattivo-del-bridge)
- [6. Configurazione H24](#6-configurazione-h24)
- [Watchdog Sinric](#watchdog-sinric)
- [7. Stato, log e gestione](#7-stato-log-e-gestione)
- [Adattamento a un altro impianto](#adattamento-a-un-altro-impianto)
- [Troubleshooting](#troubleshooting)
- [File principali](#file-principali)

---

## Come funziona

```text
Google Home
    │
    │ routine "apri cancello"
    ▼
Sinric Pro
Smart Switch "Cancello"
    │
    ▼
sinric-hikvision-bridge.py
    │
    ▼
hikvision-open-gate.ps1
    │
    ▼
hikvision-diagnose.ps1
    │
    ▼
HCNetSDK.dll x64
    │
    ▼
Monitor interno Hikvision
DS-KH6320-WTE1/EU
192.168.1.84:8000
    │
    ▼
NET_DVR_STDXMLConfig
    │
    ▼
PUT /ISAPI/AccessControl/RemoteControl/door/1
    │
    ▼
Cancello
```

Il dispositivo Sinric viene usato come **pulsante momentaneo**: quando riceve `ON`, il bridge invia il comando Hikvision e riporta subito lo switch virtuale su `OFF`.

Il bridge applica inoltre:

- cooldown di `10` secondi contro aperture duplicate;
- protezione di `8` secondi all'avvio contro un eventuale vecchio stato `ON` ripristinato dal cloud.

Per maggiori dettagli tecnici: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Configurazione di riferimento

Questa è la configurazione sulla quale il progetto è stato verificato.

| Ruolo | Nome device | Modello | IP / endpoint | Porta | Utilizzo |
|---|---|---|---|---:|---|
| Server bridge | `Home-Domotica` | Dell Latitude 7490 | IP LAN del server | — | Windows + Python + task H24 |
| Monitor interno | `Hikvision Indoor Monitor` | `DS-KH6320-WTE1/EU` | `192.168.1.84` | `8000` | **Device usato per login e apertura** |
| Postazione esterna | `Hikvision Outdoor Station` | `DS-KD8003-IME1/EU` | `192.168.1.15` | `8000` / `80` | Presente nell'impianto, non usata dal percorso di apertura |
| Device cloud | `Cancello` | Sinric Pro Smart Switch | Sinric Pro Cloud | — | Trigger usato da Google Home |

Nel setup di riferimento il comando affidabile è:

```text
HCNetSDK
   -> monitor interno 192.168.1.84
   -> NET_DVR_STDXMLConfig
   -> ISAPI AccessControl
   -> cancello
```

La postazione esterna `192.168.1.15` è documentata perché fa parte dell'impianto, ma il bridge **non effettua il login direttamente su di essa**.

Configurazione di esempio: [`hikvision-gate-config.example.json`](hikvision-gate-config.example.json).

---

## Requisiti

### Windows

Testato su:

```text
Windows 11 Pro x64
Windows PowerShell 5.1 x64
```

Il progetto usa la versione a 64 bit di Windows PowerShell:

```text
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```

La versione sotto `SysWOW64` è a 32 bit e non deve essere usata con l'HCNetSDK x64 del setup testato.

---

### Python

Testato con **Python 3.13 x64**.

Download ufficiale:

- [Python per Windows](https://www.python.org/downloads/windows/)

Per usare il progetto senza modificare gli script H24, installare Python in:

```text
C:\Home-Domotica\Python
```

Il file eseguibile deve quindi risultare:

```text
C:\Home-Domotica\Python\python.exe
```

Dipendenza Python richiesta:

```text
sinricpro
```

---

### Hikvision iVMS-4200 / HCNetSDK

Serve iVMS-4200 perché installa `HCNetSDK.dll` e le relative dipendenze.

Link ufficiale:

- [Hikvision iVMS-4200](https://www.hikvision.com/en/support/download/software/ivms4200-series/)
- [Hikvision Open Platform](https://open.hikvision.com/)

Nel setup testato sono sufficienti almeno:

- Basic Configuration
- Video
- Access Control

Non è necessario aggiungere o configurare i device dentro iVMS-4200: per questo progetto servono principalmente le librerie SDK.

Percorso verificato:

```text
C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client\HCNetSDK.dll
```

---

### Sinric Pro

Occorrono:

- account Sinric Pro;
- uno **Smart Switch**;
- Device ID;
- App Key;
- App Secret.

Link:

- [Sinric Pro](https://sinric.pro/)
- [Documentazione Sinric Pro](https://help.sinric.pro/)
- [Quickstart Sinric Pro](https://help.sinric.pro/pages/quickstarts)

---

### Google Home

Serve un account Google Home collegato a Sinric Pro tramite **Works with Google**.

Link:

- [Automazioni Google Home](https://support.google.com/googlehome/answer/16214649?hl=it)
- [Comandi iniziali, condizioni e azioni](https://support.google.com/googlehome/answer/15684394?hl=it)

---

## Installazione

### 1. Copiare il progetto

Il percorso previsto dagli script H24 è:

```text
C:\Home-Domotica\Hikvision
```

Crearlo se necessario:

```powershell
New-Item -ItemType Directory -Force C:\Home-Domotica\Hikvision
```

Copiare quindi tutti i file del progetto in quella cartella.

La struttura principale sarà:

```text
C:\Home-Domotica\
├── Python\
│   └── python.exe
│
├── Hikvision\
│   ├── sinric-hikvision-bridge.py
│   ├── hikvision-open-gate.ps1
│   ├── hikvision-diagnose.ps1
│   ├── start-sinric-bridge-interactive.ps1
│   ├── configure-hikvision-h24.ps1
│   ├── run-sinric-bridge-h24.ps1
│   ├── check-requirements.ps1
│   └── ...
│
├── Config\
└── Logs\
```

Le cartelle `Config` e `Logs` vengono create automaticamente dalla configurazione H24.

### 2. Installare la dipendenza Python

```powershell
C:\Home-Domotica\Python\python.exe -m pip install -r C:\Home-Domotica\Hikvision\requirements.txt
```

---

## 1. Verifica dei prerequisiti

Eseguire:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Home-Domotica\Hikvision\check-requirements.ps1
```

Il controllo verifica:

- PowerShell a 64 bit;
- presenza di Python;
- import del modulo `sinricpro`;
- presenza di `HCNetSDK.dll`;
- raggiungibilità TCP del monitor Hikvision sulla porta SDK.

Esempio di risultato:

```text
Check                         Status
-----                         ------
64-bit PowerShell             OK
Python executable             OK
HCNetSDK.dll                  OK
Python version                OK
Python sinricpro module       OK
Hikvision monitor SDK port    OK
```

Se uno dei controlli è `FAIL`, consultare [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

---

## 2. Test Hikvision locale

Prima di configurare Sinric Pro conviene verificare che Windows riesca a comunicare direttamente con il monitor Hikvision.

### Test login senza apertura

Aprire PowerShell:

```powershell
$env:HIKVISION_GATE_PASSWORD = '<password-hikvision>'
```

Poi:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe `
  -NoProfile `
  -ExecutionPolicy Bypass `
  -File C:\Home-Domotica\Hikvision\hikvision-diagnose.ps1 `
  -DeviceAddress 192.168.1.84 `
  -DevicePort 8000 `
  -DeviceUsername admin `
  -DevicePassword $env:HIKVISION_GATE_PASSWORD `
  -LoginOnly
```

Risultato atteso:

```text
LOGIN_OK (read-only connection; no opening command sent)
```

### Test apertura

> Il comando seguente aziona fisicamente il cancello.

```powershell
$env:HIKVISION_GATE_PASSWORD = '<password-hikvision>'
cd C:\Home-Domotica\Hikvision
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hikvision-open-gate.ps1
```

Output atteso:

```text
LOGIN_OK
OPEN_COMMAND_ACCEPTED (ISAPI tunnel; physical opening not verified)
```

Se il cancello si apre, la parte **Windows → HCNetSDK → Hikvision** è configurata correttamente.

---

## 3. Configurazione Sinric Pro

1. Accedere a [Sinric Pro](https://sinric.pro/).
2. Aprire **Devices → Add Device**.
3. Creare un **Smart Switch**.
4. Assegnargli un nome, ad esempio:

```text
Cancello
```

5. Salvare il **Device ID**.
6. Recuperare **App Key** e **App Secret** dalle credenziali Sinric Pro.
7. Se disponibile per il device, disabilitare il ripristino automatico dello stato `ON` alla riconnessione.

Il bridge contiene comunque una protezione iniziale che ignora eventuali stati `ON` ripristinati nei primi secondi dopo l'avvio.

---

## 4. Configurazione Google Home

1. Aprire Google Home.
2. Aggiungere Sinric Pro tramite **Works with Google**.
3. Verificare che compaia lo Smart Switch `Cancello`.
4. Creare una routine con comando vocale, ad esempio:

```text
apri cancello
```

5. Come azione della routine, impostare:

```text
Accendi Cancello
```

Quando Google Home accende lo switch, il bridge riceve il comando, apre il cancello e riporta lo switch Sinric su `OFF`.

---

## 5. Avvio interattivo del bridge

Prima della configurazione H24 è consigliato un test manuale.

```powershell
cd C:\Home-Domotica\Hikvision

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\start-sinric-bridge-interactive.ps1
```

Vengono richiesti:

```text
Sinric Device ID
Sinric App Key
Sinric App Secret
Hikvision device password
```

Quando il bridge è collegato:

```text
Connecting to Sinric Pro...
SinricPro SDK initialized successfully
Bridge online. Say the Google routine command when ready.
```

A questo punto provare il comando Google Home.

Nel log/terminale, all'apertura, sarà visibile qualcosa simile a:

```text
Hikvision output: LOGIN_OK
OPEN_COMMAND_ACCEPTED (ISAPI tunnel; physical opening not verified)
```

Terminare il test con:

```text
CTRL+C
```

prima di configurare la modalità H24.

---

## 6. Configurazione H24

La modalità H24 crea un'attività di **Utilità di pianificazione di Windows** che:

- parte automaticamente all'avvio del PC;
- funziona anche senza login;
- gira come account `SYSTEM`;
- continua a funzionare quando il notebook passa a batteria;
- viene riavviata automaticamente se il bridge termina;
- evita istanze duplicate.

### Configurazione iniziale

Aprire **Windows PowerShell come amministratore** ed eseguire:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\Home-Domotica\Hikvision\configure-hikvision-h24.ps1
```

Vengono richiesti:

```text
Sinric Device ID
Sinric App Key
Sinric App Secret
Password Hikvision
```

La configurazione crea:

```text
C:\Home-Domotica\Config\hikvision-sinric.dpapi.json
```

Le credenziali necessarie al funzionamento automatico vengono cifrate tramite **Windows DPAPI LocalMachine**.

Il task creato si chiama:

```text
Home-Domotica - Hikvision Sinric Bridge
```

Il log viene scritto in:

```text
C:\Home-Domotica\Logs\sinric-bridge.log
```

### Test H24

Dopo la configurazione:

1. verificare che il bridge interattivo sia chiuso;
2. provare `apri cancello`;
3. riavviare Windows;
4. non effettuare il login;
5. attendere circa 30-60 secondi;
6. provare nuovamente `apri cancello`.

Se il cancello si apre anche senza login, il bridge è operativo H24.

---

## Watchdog Sinric

Il riavvio automatico del task H24 interviene quando il processo termina. In caso di errore DNS o WebSocket, invece, Python può rimanere attivo mentre Sinric risulta offline: per questo è stato aggiunto un **watchdog separato**, eseguito come `SYSTEM` ogni **5 minuti**.

| Elemento | Nome / percorso |
|---|---|
| Task watchdog | `Home-Domotica - Sinric Watchdog` |
| Script di controllo | `C:\Home-Domotica\Hikvision\watchdog-sinric.ps1` |
| Script di installazione | `C:\Home-Domotica\Hikvision\install-sinric-watchdog.ps1` |
| Task sorvegliato | `Home-Domotica - Hikvision Sinric Bridge` |
| Log letto | `C:\Home-Domotica\Logs\sinric-bridge.log` |
| Log degli interventi | `C:\Home-Domotica\Logs\sinric-watchdog.log` |

### Controlli della versione 2

A ogni esecuzione il watchdog controlla:

1. che il task del bridge esista; se manca, scrive un errore e termina con codice `1`;
2. che il task sia `Running` e sia presente un processo `python.exe` con `sinric-hikvision-bridge.py` nella riga di comando; se uno dei due controlli fallisce, tenta il riavvio;
3. le ultime **500 righe** del log, cercando questi errori:

```text
Reconnection failed
WebSocket connection failed: ... getaddrinfo failed
WebSocket error: ... getaddrinfo failed
```

Gli errori precedenti all'ultima riga `Avvio bridge Sinric Pro -> Hikvision` trovata nella porzione di log letta vengono ignorati. Se il marcatore di avvio non è nelle ultime 500 righe, un errore presente in quelle righe può comunque provocare un riavvio.

Quando interviene, il watchdog registra il motivo, ferma il task del bridge, attende **3 secondi**, lo avvia nuovamente e attende altri **5 secondi** prima di terminare. Non invia direttamente comandi di apertura del cancello.

Il controllo periodico permette di tentare il recupero al giro successivo, normalmente entro circa 5 minuti. La riconnessione richiede comunque che rete, DNS e servizio Sinric tornino disponibili. Il controllo si basa su task, processo e log: non è una verifica completa della connessione cloud e non rileva tutti i possibili blocchi.

### Installazione sul server

I due script del watchdog sono distribuiti separatamente dal pacchetto base presente in questa cartella. Copiare `watchdog-sinric.ps1` **versione 2** e `install-sinric-watchdog.ps1` in `C:\Home-Domotica\Hikvision`, dopo aver configurato il bridge H24.

Da **Windows PowerShell come amministratore**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\Home-Domotica\Hikvision\install-sinric-watchdog.ps1
```

L'installer registra il task ogni 5 minuti come `SYSTEM` e avvia subito un controllo. Per aggiornare un watchdog già installato alla v2 basta sostituire `watchdog-sinric.ps1` nello stesso percorso; non occorre ricreare il task.

### Stato e log

```powershell
Get-ScheduledTaskInfo -TaskName 'Home-Domotica - Sinric Watchdog' |
  Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Il watchdog è un controllo breve: tra due esecuzioni il suo stato normalmente è `Ready`, mentre il bridge rimane `Running`. `LastTaskResult = 0` indica che lo script è terminato con quel codice; non certifica da solo che Sinric sia online o che un riavvio sia riuscito.

Per eseguire subito un controllo (può riavviare il bridge se rileva un problema):

```powershell
Start-ScheduledTask -TaskName 'Home-Domotica - Sinric Watchdog'
```

Per leggere gli interventi:

```powershell
$watchdogLog = 'C:\Home-Domotica\Logs\sinric-watchdog.log'
if (Test-Path -LiteralPath $watchdogLog) {
  Get-Content -LiteralPath $watchdogLog -Tail 20
} else {
  Write-Host 'Nessun log watchdog presente: controllare anche lo stato del task.'
}
```

Il log viene creato solo quando il watchdog tenta un riavvio o rileva che il task del bridge manca. La sua assenza può quindi essere normale. Un intervento può riportare:

```text
Riavvio bridge: Sinric offline dopo l'ultimo avvio: ...
```

Per verificare il recupero, controllare il nuovo avvio in `sinric-bridge.log` e lo stato del dispositivo nel portale Sinric. Non aggiungere errori artificiali al log in uso: il bridge può tenerlo aperto in scrittura esclusiva e il watchdog li tratterebbe come errori reali.

### Manutenzione e rimozione

Prima di arrestare volontariamente il bridge, disabilitare e fermare anche il watchdog, altrimenti tenterà di riavviarlo al controllo successivo:

```powershell
Disable-ScheduledTask -TaskName 'Home-Domotica - Sinric Watchdog'
Stop-ScheduledTask -TaskName 'Home-Domotica - Sinric Watchdog'
Stop-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
```

Al termine della manutenzione:

```powershell
Start-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
Enable-ScheduledTask -TaskName 'Home-Domotica - Sinric Watchdog'
```

Lo script `uninstall-hikvision-h24.ps1` rimuove soltanto il task del bridge. Per rimuovere anche il watchdog, disabilitarlo e fermarlo come sopra, quindi eseguire:

```powershell
Unregister-ScheduledTask -TaskName 'Home-Domotica - Sinric Watchdog' -Confirm:$false
```

---

## 7. Stato, log e gestione

### Stato rapido

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\Home-Domotica\Hikvision\show-status.ps1
```

Oppure:

```powershell
Get-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
Get-ScheduledTaskInfo -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
```

Con il bridge attivo lo stato normalmente risulta:

```text
Running
```

### Ultime righe del log

```powershell
Get-Content C:\Home-Domotica\Logs\sinric-bridge.log -Tail 50
```

### Log in tempo reale

```powershell
Get-Content C:\Home-Domotica\Logs\sinric-bridge.log -Wait -Tail 20
```

### Arrestare il bridge H24

Se è installato il watchdog, seguire prima i passaggi di [manutenzione](#manutenzione-e-rimozione) per evitare che riavvii il bridge.

```powershell
Stop-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
```

### Avviarlo manualmente

```powershell
Start-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
```

### Modificare le credenziali

Rieseguire:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\Home-Domotica\Hikvision\configure-hikvision-h24.ps1
```

### Rimuovere la modalità H24

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\Home-Domotica\Hikvision\uninstall-hikvision-h24.ps1
```

---

## Adattamento a un altro impianto

Il setup di riferimento usa:

```text
Monitor interno:  192.168.1.84
Porta SDK:        8000
Username:         admin
```

Per un altro impianto è possibile usare variabili d'ambiente.

### IP monitor

```powershell
$env:HIKVISION_MONITOR_IP = '192.168.1.100'
```

### Porta SDK

```powershell
$env:HIKVISION_SDK_PORT = '8000'
```

### Username

```powershell
$env:HIKVISION_USERNAME = 'admin'
```

### Cartella HCNetSDK

Percorso predefinito:

```text
C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client
```

Override:

```powershell
$env:HIKVISION_SDK_DIR = 'C:\Percorso\HCNetSDK'
```

Per verificare dove si trova `HCNetSDK.dll`:

```powershell
Get-ChildItem "C:\Program Files*" -Recurse -Filter HCNetSDK.dll `
  -ErrorAction SilentlyContinue |
Select-Object FullName
```

> Gli override sono utili per i test manuali. Gli script H24 inclusi sono predisposti per i percorsi della configurazione di riferimento.

---

## Troubleshooting

La guida completa è disponibile qui:

[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)

Problemi documentati:

| Problema | Causa tipica |
|---|---|
| `L'esecuzione di script è disabilitata` | Execution Policy PowerShell |
| `BadImageFormatException / 0x8007000B` | mismatch x86/x64 |
| `SDK_ERROR=17` | struttura SDK non compatibile x64 |
| `ProtectedData` non trovato | assembly `System.Security` non caricato |
| Task `Ready`, risultato `1` | output Sinric su STDERR interpretato da PowerShell |
| `HCNetSDK.dll` non trovata | iVMS-4200 non installato o percorso differente |
| `LOGIN_FAILED` | IP, porta, username/password o rete |
| Aperture duplicate | routine duplicata o cooldown da controllare |

Test rapido della porta Hikvision:

```powershell
Test-NetConnection 192.168.1.84 -Port 8000
```

---

## File principali

| File | Funzione |
|---|---|
| `sinric-hikvision-bridge.py` | bridge Sinric Pro → Hikvision |
| `hikvision-open-gate.ps1` | comando di apertura del cancello |
| `hikvision-diagnose.ps1` | login SDK, diagnostica e chiamata ISAPI |
| `start-sinric-bridge-interactive.ps1` | avvio manuale per collaudo |
| `configure-hikvision-h24.ps1` | configura credenziali e task H24 |
| `run-sinric-bridge-h24.ps1` | launcher automatico eseguito come SYSTEM |
| `check-requirements.ps1` | verifica prerequisiti |
| `show-status.ps1` | mostra stato del servizio e log |
| `uninstall-hikvision-h24.ps1` | rimuove il task H24 |
| `requirements.txt` | dipendenze Python |
| `hikvision-gate-config.example.json` | esempio configurazione dell'impianto |

---

## Stato della configurazione di riferimento

Testato con successo su:

```text
Windows 11 Pro x64
Python 3.13
iVMS-4200 / HCNetSDK x64
Hikvision DS-KH6320-WTE1/EU
Hikvision DS-KD8003-IME1/EU
Sinric Pro Smart Switch
Google Home
```

Verifiche completate:

```text
[OK] Login Hikvision tramite HCNetSDK
[OK] Apertura locale
[OK] Bridge Python Sinric Pro
[OK] Comando Google Home
[OK] Avvio automatico H24
[OK] Funzionamento dopo reboot senza login
```
