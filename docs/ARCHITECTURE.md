# Architettura

## Percorso del comando

```text
Google Home
    │
    ▼
Routine / automazione
    │
    ▼
Sinric Pro Smart Switch "Cancello"
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

## Perché viene usato il monitor interno

Nella configurazione testata, la postazione esterna `DS-KD8003-IME1/EU`
all'indirizzo `192.168.1.15` era raggiungibile per le funzioni video, ma il
percorso di login SDK diretto testato non risultava utilizzabile.

Il percorso funzionante consiste nel collegarsi al monitor interno
`DS-KH6320-WTE1/EU` all'indirizzo `192.168.1.84`, porta SDK `8000`, e inviare
la richiesta Access Control tramite `NET_DVR_STDXMLConfig`.

## Modalità H24

```text
Avvio Windows
    │
    ▼
Utilità di pianificazione
    │
    ▼
run-sinric-bridge-h24.ps1
eseguito come SYSTEM
    │
    ├──► credenziali DPAPI
    │
    ├──► Python bridge
    │       │
    │       ├──► Sinric Pro Cloud
    │       └──► Hikvision LAN
    │
    └──► C:\Home-Domotica\Logs\sinric-bridge.log
```

Il task viene eseguito anche senza login dell'utente ed è configurato per
continuare a funzionare quando il computer passa all'alimentazione a batteria.
