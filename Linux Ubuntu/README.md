# OpenSSL-PKI-Docker-Automation (Ubuntu Edition)

Ein vollständig automatisiertes Toolkit zur Erstellung einer kompletten **Public Key Infrastructure (PKI)** unter **Ubuntu/Linux** – inklusive Root-CA, Intermediate-CA, Server-/Client-Zertifikaten, CRL/OCSP-Unterstützung und einer fertig konfigurierten **Nginx-Docker-Umgebung** für mTLS-Tests.

Die gesamte PKI-Struktur (inkl. Zertifikate, Keys, CRLs, OCSP) wird durch ein einziges Skript automatisch erzeugt.

---

## 🚀 Features

* 🔐 Automatisierte Erstellung von **Root- & Intermediate-CA**
* 📜 Erstellung von **Server- & Client-Zertifikaten**
* ❌ Zertifikatswiderruf + automatische **CRL-Erzeugung**
* 🟢 **OCSP-Responder** zum Prüfen von Zertifikatsstatus
* 🐳 **Docker + Nginx (mTLS)** – sofort einsatzbereit
* 🗂️ Reproduzierbare, saubere Ordnerstruktur
* 🎯 Perfekt für PKI-Labs, Security-Schulungen, Zero-Trust-Tests

---

## 📦 Voraussetzungen

### Unter **Ubuntu / Debian-basierte Systeme**

Installiere die benötigten Pakete:

```bash
sudo apt update
sudo apt install -y openssl docker.io docker-compose curl wget
```

> Hinweis: Ubuntu verwendet bereits OpenSSL 3.x
> Keine zusätzlichen Installationen notwendig.

Docker aktivieren:

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

*(Abmelden/Anmelden nötig, damit die Docker-Gruppe aktiv wird.)*

---

## 📁 Projektstruktur

Die generierte PKI-Struktur sieht so aus:

```
project/
  config/
    pki-vars.conf
    openssl-root.cnf
    openssl-intermediate.cnf

  pki/
    root/
    intermediate/
    server/
    client/

  docker/
    nginx.conf
    Dockerfile
    docker-compose.yml

  setup_pki_nginx.sh
```

---

## 🛠️ Installation & Verwendung unter Ubuntu

### 1. Repository klonen

```bash
git clone https://github.com/0xWunda/OpenSSL-PKI-Docker-Automation
cd OpenSSL-PKI-Docker-Automation
```

### 2. Setup-Skript ausführbar machen

```bash
chmod +x setup_pki_nginx.sh
```

### 3. PKI + Docker-Setup generieren

```bash
./setup_pki_nginx.sh
```

Das Skript erzeugt:

* Root-CA
* Intermediate-CA
* Server-/Client-Zertifikate
* CA-Chain
* CRL
* OCSP-Konfiguration
* Docker/Nginx-mTLS-Umgebung

---

## 🔥 OCSP-Responder starten

```bash
openssl ocsp \
  -index pki/intermediate/index.txt \
  -port 2560 \
  -CA pki/intermediate/certs/ca-chain.cert.pem \
  -rkey pki/intermediate/private/intermediate.key.pem \
  -rsigner pki/intermediate/certs/intermediate.cert.pem \
  -text
```

Erwartete Ausgabe:

```
Waiting for OCSP client connections...
```

---

## 🧪 OCSP-Abfragen durchführen

Neues Terminal öffnen:

```bash
cd OpenSSL-PKI-Docker-Automation
```

### Server-Zertifikat prüfen

```bash
openssl ocsp \
  -issuer pki/intermediate/certs/intermediate.cert.pem \
  -cert pki/server/certs/server.cert.pem \
  -CAfile pki/intermediate/certs/ca-chain.cert.pem \
  -url http://127.0.0.1:2560 \
  -resp_text
```

### Client-Zertifikat prüfen

```bash
openssl ocsp \
  -issuer pki/intermediate/certs/intermediate.cert.pem \
  -cert pki/client/certs/client.cert.pem \
  -CAfile pki/intermediate/certs/ca-chain.cert.pem \
  -url http://127.0.0.1:2560 \
  -resp_text
```

---

## ❌ Zertifikat widerrufen (CRL + OCSP)

### Environment-Variablen setzen

```bash
export CRL_URL="http://localhost:8080/crl/intermediate.crl.pem"
export OCSP_URL="http://127.0.0.1:2560"
```

### Zertifikat widerrufen

```bash
openssl ca \
  -config pki/intermediate/openssl.cnf \
  -revoke pki/client/certs/client.cert.pem
```

### Neue CRL erzeugen

```bash
openssl ca \
  -config pki/intermediate/openssl.cnf \
  -gencrl -out pki/intermediate/crl/intermediate.crl.pem
```

### OCSP erneut testen

```bash
openssl ocsp \
  -issuer pki/intermediate/certs/intermediate.cert.pem \
  -cert pki/client/certs/client.cert.pem \
  -CAfile pki/intermediate/certs/ca-chain.cert.pem \
  -url http://127.0.0.1:2560 \
  -resp_text
```

Erwartetes Ergebnis:

```
client.cert.pem: revoked
```

---

## 🐳 Docker & Nginx starten (mTLS aktiv)

```bash
cd docker
docker compose up --build
```

### Zugriff per Browser (ohne mTLS)

👉 **[https://localhost](https://localhost)**

### mTLS-Zugriff via OpenSSL

```bash
openssl s_client \
  -connect localhost:443 \
  -servername nginx.local \
  -cert ../pki/client/certs/client.cert.pem \
  -key ../pki/client/private/client.key.pem
```

---

## 🧰 Troubleshooting

### ❗ Fehler: “variable has no value”

Fehlende ENV-Variablen.

Fix:

```bash
export CRL_URL="http://localhost:8080/crl/intermediate.crl.pem"
export OCSP_URL="http://127.0.0.1:2560"
```

---

### ❗ OCSP: “unexpected content type: text/html”

Falscher Port (443 statt 2560).

Richtig:

```bash
-url http://127.0.0.1:2560
```

---

### ❗ “Could not open file… intermediate.cert.pem”

Falsches Verzeichnis → Projektordner öffnen:

```bash
cd OpenSSL-PKI-Docker-Automation
```

---

## 📜 Lizenz

MIT License – frei für PKI-Labs, Ausbildung, Security-Tests & mTLS-Entwicklung.

---

## ⭐ Feedback

Wenn dir das Projekt hilft:

* ⭐ GitHub-Star dalassen
* Issues für Fragen & Vorschläge
* Pull Requests willkommen

---
