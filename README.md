# Hikvision Gate Bridge — Google Home + Sinric Pro + HCNetSDK

Bridge Windows/Python per aprire un cancello Hikvision con un comando vocale Google Home, passando da Sinric Pro e dall'HCNetSDK installato con iVMS-4200.

La catena è stata verificata realmente su Windows 11 x64: il comando vocale arriva a Sinric Pro, il bridge Python richiama PowerShell, l'SDK Hikvision effettua il login sul monitor interno e inoltra il comando ISAPI di apertura.

> **Nota importante:** questo progetto aziona un dispositivo fisico. Usalo solo su impianti che possiedi o amministri e mantieni sempre un metodo di apertura locale indipendente. Le automazioni cloud sono un livello di comodità, non un controllo safety/security-critical.

## Indice

- [Cosa fa](#cosa-fa)
- [Architettura](#architettura)
- [Configurazione testata e IP](#configurazione-testata-e-ip)
- [Requisiti](#requisiti)
- [Installazione rapida](#installazione-rapida)
- [Funzione 1 — test Hikvision locale](#funzione-1--test-hikvision-locale)
- [Funzione 2 — bridge Sinric Pro interattivo](#funzione-2--bridge-sinric-pro-interattivo)
- [Funzione 3 — Google Home](#funzione-3--google-home)
- [Funzione 4 — funzionamento H24 senza login](#funzione-4--funzionamento-h24-senza-login)
- [Funzione 5 — stato e log](#funzione-5--stato-e-log)
- [Adattarlo a un altro impianto](#adattarlo-a-un-altro-impianto)
- [Struttura del repository](#struttura-del-repository)
- [Sicurezza](#sicurezza)
- [Troubleshooting](#troubleshooting)
- [Pubblicazione su GitHub](#pubblicazione-su-github)

---

## Cosa fa

Il progetto fornisce cinque funzioni principali:

1. **Apertura locale del cancello** via HCNetSDK/ISAPI.
2. **Bridge Python Sinric Pro → Hikvision** con Smart Switch momentaneo.
3. **Comando vocale Google Home** tramite routine/automazione.
4. **Avvio H24 automatico** all'accensione di Windows, anche senza login.
5. **Diagnostica e log** per rete, SDK, Python e task pianificato.

Il bridge include inoltre due protezioni semplici:

- cooldown predefinito di `10` secondi contro comandi duplicati;
- finestra iniziale di `8` secondi in cui ignora un eventuale vecchio stato `ON` ripristinato da Sinric Pro.

---

## Architettura

```mermaid
flowchart TD
    A[Voce: "apri cancello"] --> B[Google Home]
    B --> C[Sinric Pro Smart Switch "Cancello"]
    C --> D[sinric-hikvision-bridge.py]
    D --> E[hikvision-open-gate.ps1]
    E --> F[hikvision-diagnose.ps1]
    F --> G[HCNetSDK.dll x64]
    G --> H[Monitor interno Hikvision\nDS-KH6320-WTE1/EU\n192.168.1.84:8000]
    H --> I[NET_DVR_STDXMLConfig]
    I --> J[PUT /ISAPI/AccessControl/RemoteControl/door/1]
    J --> K[Cancello]
```

Dettagli aggiuntivi: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Configurazione testata e IP

| Ruolo | Nome device | Modello | IP | Porta | Note |
|---|---|---|---|---:|---|
| Server bridge | Windows Home-Domotica | Dell Latitude 7490 | DHCP/statico a scelta | — | Windows 11 Pro x64, Python 3.13.15 |
| Monitor interno | Hikvision Indoor Monitor | `DS-KH6320-WTE1/EU` | `192.168.1.84` | `8000` | **Device usato dal bridge** |
| Postazione esterna | Hikvision Outdoor Station | `DS-KD8003-IME1/EU` | `192.168.1.15` | `8000` / `80` | Non usata per il login del percorso funzionante |
| Device cloud | Sinric Pro Smart Switch | `Cancello` | cloud | — | Trigger momentaneo Google Home |

Nel setup verificato, la postazione esterna rispondeva al video ma non accettava il login SDK diretto dalla LAN. Il percorso affidabile è risultato:

```text
HCNetSDK -> monitor interno 192.168.1.84 -> NET_DVR_STDXMLConfig -> ISAPI AccessControl -> cancello
```

Configurazione tecnica di esempio: [`hikvision-gate-config.example.json`](hikvision-gate-config.example.json).

---

## Requisiti

### Sistema operativo

- Windows 11 x64 **testato**.
- Windows 10/11 x64 dovrebbe essere il target naturale, ma questo repository è stato verificato sul sistema indicato sopra.
- Windows PowerShell 5.1 64 bit (`System32`).

### Python

Testato con **Python 3.13.15 x64**.

Download ufficiale:

- [Python for Windows](https://www.python.org/downloads/windows/)

Percorso usato nel setup H24:

```text
C:\Home-Domotica\Python\python.exe
```

Il bridge usa il pacchetto:

```text
sinricpro
```

installabile da `requirements.txt`.

### Hikvision iVMS-4200 / HCNetSDK

Testato con **iVMS-4200 V3.14.1.4_E**.

- [Download ufficiale iVMS-4200](https://www.hikvision.com/en/support/download/software/ivms4200-series/)
- [Hikvision Open Platform](https://open.hikvision.com/)

Nel setup testato sono stati installati almeno:

- Basic Configuration
- Video
- Access Control

Non è necessario configurare i device dentro iVMS-4200 per questo bridge: ci interessa soprattutto che siano presenti `HCNetSDK.dll` e le sue dipendenze.

Percorso verificato:

```text
C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client\HCNetSDK.dll
```

La DLL installata è **x64**. Per questo il repository usa PowerShell 64 bit sotto `System32`, non `SysWOW64`.

### Sinric Pro

- account Sinric Pro;
- Smart Switch chiamato, ad esempio, `Cancello`;
- Device ID;
- App Key;
- App Secret.

Link utili:

- [Sinric Pro](https://sinric.pro/)
- [Documentazione Sinric Pro](https://help.sinric.pro/)
- [Quickstart Sinric Pro](https://help.sinric.pro/pages/quickstarts)

### Google Home

Serve collegare Sinric Pro a Google Home tramite **Works with Google** e creare una routine/automazione che accenda lo Smart Switch `Cancello`.

- [Gestire le automazioni Google Home](https://support.google.com/googlehome/answer/16214649?hl=it)
- [Comandi iniziali, condizioni e azioni](https://support.google.com/googlehome/answer/15684394?hl=it)

---

## Installazione rapida

### 1. Metti il repository nel percorso previsto

Per usare gli script H24 senza modificarli, usa:

```text
C:\Home-Domotica\Hikvision
```

Esempio:

```powershell
New-Item -ItemType Directory -Force C:\Home-Domotica\Hikvision
```

Poi copia/clona qui il repository.

### 2. Installa la dipendenza Python

```powershell
C:\Home-Domotica\Python\python.exe -m pip install -r C:\Home-Domotica\Hikvision\requirements.txt
```

### 3. Controlla i prerequisiti

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Home-Domotica\Hikvision\check-requirements.ps1
```

Il controllo verifica:

- processo PowerShell a 64 bit;
- Python;
- import `sinricpro`;
- presenza `HCNetSDK.dll`;
- raggiungibilità TCP del monitor Hikvision sulla porta SDK.

---

## Funzione 1 — test Hikvision locale

### Test sicuro: solo login, nessuna apertura

Apri PowerShell e imposta temporaneamente la password:

```powershell
$env:HIKVISION_GATE_PASSWORD = '<password>'
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

### Test di apertura reale

> Questo comando aziona fisicamente il cancello.

```powershell
$env:HIKVISION_GATE_PASSWORD = '<password>'
cd C:\Home-Domotica\Hikvision
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hikvision-open-gate.ps1
```

Output atteso:

```text
LOGIN_OK
OPEN_COMMAND_ACCEPTED (ISAPI tunnel; physical opening not verified)
```

La richiesta usata è:

```text
PUT /ISAPI/AccessControl/RemoteControl/door/1
```

con body:

```xml
<RemoteControlDoor version="2.0" xmlns="http://www.isapi.org/ver20/XMLSchema">
  <channelNo>1</channelNo>
  <cmd>open</cmd>
  <controlType>monitor</controlType>
</RemoteControlDoor>
```

---

## Funzione 2 — bridge Sinric Pro interattivo

Questo è il modo migliore per collaudare il bridge prima di renderlo H24.

```powershell
cd C:\Home-Domotica\Hikvision
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start-sinric-bridge-interactive.ps1
```

Vengono chiesti:

- Sinric Device ID;
- Sinric App Key;
- Sinric App Secret;
- password Hikvision.

App Secret e password Hikvision vengono digitati come `SecureString` e non vengono scritti nei file del repository.

Quando è online:

```text
Connecting to Sinric Pro...
SinricPro SDK initialized successfully
Bridge online. Say the Google routine command when ready.
```

Non avviare contemporaneamente il bridge interattivo e quello H24 con lo stesso Device ID.

---

## Funzione 3 — Google Home

### Configurazione Sinric Pro

1. In Sinric Pro apri **Devices -> Add Device -> Smart Switch**.
2. Assegna un nome, ad esempio `Cancello`.
3. Copia il **Device ID**.
4. In **Credentials** recupera/crea **App Key** e **App Secret**.
5. Se disponibile, disabilita il ripristino automatico dello stato `ON` alla riconnessione.

Il bridge contiene comunque una protezione che ignora un vecchio `ON` nei primi secondi dopo l'avvio.

### Configurazione Google Home

1. Collega Sinric Pro tramite **Aggiungi dispositivo -> Works with Google**.
2. Verifica che compaia lo switch `Cancello`.
3. Crea una routine/automazione con comando vocale, per esempio:

```text
apri cancello
```

4. Come azione, **accendi** lo switch Sinric `Cancello`.

Lo switch è volutamente momentaneo: dopo il comando, il bridge segnala nuovamente lo stato `OFF`.

---

## Funzione 4 — funzionamento H24 senza login

Il setup H24 usa **Utilità di pianificazione di Windows** e avvia il bridge come `SYSTEM`:

- all'avvio del PC;
- senza login dell'utente;
- anche a batteria;
- senza fermarsi quando il notebook passa da rete elettrica a batteria;
- con riavvio automatico dopo un errore;
- senza timeout massimo di esecuzione.

### Configurazione iniziale

Apri **Windows PowerShell come amministratore**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Home-Domotica\Hikvision\configure-hikvision-h24.ps1
```

Inserisci:

- Sinric Device ID;
- Sinric App Key;
- Sinric App Secret;
- password Hikvision.

Le credenziali vengono cifrate tramite **Windows DPAPI LocalMachine** e salvate fuori dal repository:

```text
C:\Home-Domotica\Config\hikvision-sinric.dpapi.json
```

Il file viene ACL-limitato a `SYSTEM` e Administrators.

Il task creato si chiama:

```text
Home-Domotica - Hikvision Sinric Bridge
```

### Test H24 definitivo

1. Verifica che il bridge interattivo sia chiuso.
2. Esegui il setup H24.
3. Prova il comando vocale.
4. Riavvia Windows.
5. **Non effettuare login.**
6. Attendi circa 30-60 secondi.
7. Prova nuovamente `apri cancello`.

Se funziona, il bridge è autonomo H24.

---

## Funzione 5 — stato e log

### Stato rapido

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Home-Domotica\Hikvision\show-status.ps1
```

Oppure:

```powershell
Get-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
Get-ScheduledTaskInfo -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
```

Con il bridge attivo lo stato atteso è:

```text
Running
```

### Log

Ultime 50 righe:

```powershell
Get-Content C:\Home-Domotica\Logs\sinric-bridge.log -Tail 50
```

Live:

```powershell
Get-Content C:\Home-Domotica\Logs\sinric-bridge.log -Wait -Tail 20
```

### Stop / start manuale del task

```powershell
Stop-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
Start-ScheduledTask -TaskName 'Home-Domotica - Hikvision Sinric Bridge'
```

### Rimozione del task H24

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Home-Domotica\Hikvision\uninstall-hikvision-h24.ps1
```

Questo rimuove il task ma **non** cancella automaticamente il file DPAPI con le credenziali.

---

## Adattarlo a un altro impianto

Per un altro impianto Hikvision controlla almeno questi valori.

### IP monitor interno

Default:

```text
192.168.1.84
```

Puoi sovrascriverlo nella sessione:

```powershell
$env:HIKVISION_MONITOR_IP = '192.168.1.100'
```

### Porta SDK

Default:

```text
8000
```

Override:

```powershell
$env:HIKVISION_SDK_PORT = '8000'
```

### Username Hikvision

Default:

```text
admin
```

Override:

```powershell
$env:HIKVISION_USERNAME = 'nomeutente'
```

### Directory HCNetSDK

Default testato:

```text
C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client
```

Override:

```powershell
$env:HIKVISION_SDK_DIR = 'C:\Percorso\Della\SDK'
```

> Gli override sopra valgono per il processo corrente. Per il task H24, il repository è predisposto sul percorso/configurazione testati; se l'impianto usa valori diversi, aggiorna i default negli script o estendi il launcher H24 con gli stessi valori prima della messa in servizio.

### IP postazione esterna

Nel setup di riferimento:

```text
DS-KD8003-IME1/EU -> 192.168.1.15
```

È documentato perché fa parte dell'impianto, ma **non è il target del comando di apertura funzionante**.

---

## Struttura del repository

```text
hikvision-sinric-gate-bridge/
├── README.md
├── SECURITY.md
├── CHANGELOG.md
├── requirements.txt
├── .gitignore
├── .github/workflows/validate.yml
├── sinric-hikvision-bridge.py
├── hikvision-open-gate.ps1
├── hikvision-diagnose.ps1
├── run-sinric-bridge.ps1
├── start-sinric-bridge-interactive.ps1
├── configure-hikvision-h24.ps1
├── run-sinric-bridge-h24.ps1
├── check-requirements.ps1
├── show-status.ps1
├── uninstall-hikvision-h24.ps1
├── sinric-bridge.env.example.ps1
├── hikvision-gate-config.example.json
└── docs/
    ├── ARCHITECTURE.md
    └── TROUBLESHOOTING.md
```

### Ruolo dei file principali

| File | Funzione |
|---|---|
| `sinric-hikvision-bridge.py` | client Sinric Pro e logica Smart Switch momentaneo |
| `hikvision-open-gate.ps1` | wrapper di apertura del cancello |
| `hikvision-diagnose.ps1` | interop .NET ↔ HCNetSDK e comando ISAPI |
| `start-sinric-bridge-interactive.ps1` | test manuale con prompt credenziali |
| `configure-hikvision-h24.ps1` | crea credenziali DPAPI + scheduled task |
| `run-sinric-bridge-h24.ps1` | launcher SYSTEM H24 e gestione log |
| `check-requirements.ps1` | verifica prerequisiti |
| `show-status.ps1` | riepilogo stato task + log |

---

## Sicurezza

Il repository **non deve contenere credenziali reali**.

Non committare mai:

```text
SINRICPRO_APP_SECRET
HIKVISION_GATE_PASSWORD
file DPAPI generato
log locali
file .env compilati
```

Anche Device ID e App Key sono lasciati vuoti negli esempi pubblici.

Consulta [`SECURITY.md`](SECURITY.md) prima di pubblicare il repository.

---

## Troubleshooting

Guida completa:

[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)

Include le soluzioni per:

- Execution Policy;
- `BadImageFormatException / 0x8007000B`;
- mismatch x86/x64;
- `SDK_ERROR=17`;
- `ProtectedData` non trovato in PowerShell 5.1;
- task H24 che termina con `LastTaskResult = 1`;
- `HCNetSDK.dll` non trovata;
- login Hikvision fallito;
- comandi duplicati;
- log con output binario.

---

## Pubblicazione su GitHub

Prima controlla che non ci siano segreti:

```powershell
cd C:\Home-Domotica\Hikvision
git status
```

Poi, per un nuovo repository:

```powershell
git init
git add .
git commit -m "Initial working Hikvision Sinric gate bridge"
git branch -M main
git remote add origin https://github.com/USERNAME/hikvision-sinric-gate-bridge.git
git push -u origin main
```

### Licenza

Questo pacchetto non inserisce automaticamente una licenza software. Prima di renderlo pubblico, scegli esplicitamente la licenza che vuoi applicare (ad esempio MIT se vuoi permettere riuso ampio con poche condizioni).

---

## Stato del progetto

Configurazione di riferimento verificata il **28 settembre 2026**:

- apertura locale Hikvision: OK;
- HCNetSDK x64: OK;
- Sinric Pro Python bridge: OK;
- Google Home voice routine: OK;
- avvio H24 come `SYSTEM`: OK;
- funzionamento dopo reboot senza login: OK.
