# OpenSSL-PKI-Docker-Automation

Ein vollständig automatisiertes Toolkit zur Erstellung einer kompletten Public Key Infrastructure (PKI) unter macOS – inklusive Root-CA, Intermediate-CA, Server-/Client-Zertifikaten, CRL/OCSP-Unterstützung und einer fertig konfigurierten Nginx-Docker-Umgebung für mTLS-Tests.

Die gesamte PKI-Struktur (inkl. Zertifikate, Keys, CRLs, OCSP) wird durch ein einziges Skript automatisch erzeugt.

---

## 🚀 Features

- 🔐 Automatisierte Erstellung einer **Root-CA** und **Intermediate-CA**
- 📜 Generierung von **Server- & Client-Zertifikaten**
- ❌ Zertifikats-Revocation + automatische **CRL-Erzeugung**
- 🟢 Lokaler **OCSP-Responder** für Status-Abfragen
- 🐳 **Docker + Nginx** Setup für TLS + mTLS (Client Authentication)
- 🗂️ Saubere & reproduzierbare Ordnerstruktur
- 🎯 Perfekt für Entwickler, Labs, Schulungen & Zero-Trust-Tests

---

## 📦 Voraussetzungen

### Unter macOS:

1. **Homebrew**
2. **OpenSSL 3**
3. **Docker Desktop**

Installation:

```bash
brew install openssl@3
brew install docker docker-compose
````

Optional:

```bash
brew install curl wget
```

---

## 📁 Projektstruktur

Nach der Installation sieht die PKI-Struktur so aus:

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

## 🛠️ Installation & Verwendung unter macOS

### 1. Repo klonen

```bash
git clone https://github.com/0xWunda/OpenSSL-PKI-Docker-Automation
cd OpenSSL-PKI-Docker-Automation
```

### 2. Setup-Skript ausführbar machen

```bash
chmod +x setup_pki_nginx.sh
```

### 3. Vollständige PKI erstellen

```bash
./setup_pki_nginx.sh
```

Das Skript:

* erstellt Root-CA & Intermediate-CA
* generiert Server- & Client-Zertifikate
* erstellt die CA-Chain
* initialisiert die CRL
* erzeugt die Docker/Nginx-Konfiguration

Nach Ausführung ist die gesamte PKI komplett eingerichtet.

---

## 🔥 OCSP-Responder starten

Im Projektordner:

```bash
/opt/homebrew/opt/openssl@3/bin/openssl ocsp \
  -index pki/intermediate/index.txt \
  -port 2560 \
  -CA pki/intermediate/certs/ca-chain.cert.pem \
  -rkey pki/intermediate/private/intermediate.key.pem \
  -rsigner pki/intermediate/certs/intermediate.cert.pem \
  -text
```

Wenn erfolgreich:

```
Waiting for OCSP client connections...
```

(Terminal offen lassen.)

---

## 🧪 OCSP-Abfragen durchführen

Neues Terminal öffnen:

```bash
cd OpenSSL-PKI-Docker-Automation
```

### Server-Zertifikat prüfen

```bash
/opt/homebrew/opt/openssl@3/bin/openssl ocsp \
  -issuer pki/intermediate/certs/intermediate.cert.pem \
  -cert pki/server/certs/server.cert.pem \
  -CAfile pki/intermediate/certs/ca-chain.cert.pem \
  -url http://127.0.0.1:2560 \
  -resp_text
```

### Client-Zertifikat prüfen

```bash
/opt/homebrew/opt/openssl@3/bin/openssl ocsp \
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

### Client widerrufen

```bash
/opt/homebrew/opt/openssl@3/bin/openssl ca \
  -config pki/intermediate/openssl.cnf \
  -revoke pki/client/certs/client.cert.pem
```

### Neue CRL erzeugen

```bash
/opt/homebrew/opt/openssl@3/bin/openssl ca \
  -config pki/intermediate/openssl.cnf \
  -gencrl -out pki/intermediate/crl/intermediate.crl.pem
```

### OCSP erneut abfragen

```bash
/opt/homebrew/opt/openssl@3/bin/openssl ocsp \
  -issuer pki/intermediate/certs/intermediate.cert.pem \
  -cert pki/client/certs/client.cert.pem \
  -CAfile pki/intermediate/certs/ca-chain.cert.pem \
  -url http://127.0.0.1:2560 \
  -resp_text
```

Erwartet:

```
client.cert.pem: revoked
```

---

## 🐳 Docker & Nginx starten (mTLS aktiv)

Ins Docker-Verzeichnis:

```bash
cd docker
docker compose up --build
```

### Zugriff per Browser (ohne mTLS):

👉 [https://localhost](https://localhost)

### Zugriff mit Client-Zertifikat (OpenSSL):

```bash
/opt/homebrew/opt/openssl@3/bin/openssl s_client \
  -connect localhost:443 \
  -servername nginx.local \
  -cert ../pki/client/certs/client.cert.pem \
  -key ../pki/client/private/client.key.pem
```

---

## 🧰 Troubleshooting

### ❗ Fehler: “variable has no value”

Ursache: CRL_URL oder OCSP_URL fehlen.

Fix:

```bash
export CRL_URL="http://localhost:8080/crl/intermediate.crl.pem"
export OCSP_URL="http://127.0.0.1:2560"
```

---

### ❗ OCSP: “unexpected content type: text/html”

Ursache: falscher Port → du fragst Nginx (443) statt OCSP (2560) ab.

Nutze:

```bash
-url http://127.0.0.1:2560
```

---

### ❗ “Could not open file… intermediate.cert.pem”

Ursache: falscher Ordner.

Fix:

```bash
cd OpenSSL-PKI-Docker-Automation
```

---

## 📜 Lizenz

MIT License – frei verwendbar für Entwicklung, PKI-Tests, mTLS-Projekte & Security-Labs.

---

## ⭐ Feedback

Wenn dir dieses Projekt gefällt:

* Gib dem Repo einen ⭐
* Erstelle Issues bei Fragen oder Bugs
* Pull Requests sind willkommen

```

