# OpenSSL-PKI-Docker-Automation

Ein automatisiertes Toolkit zur Erstellung einer vollständigen Public Key Infrastructure (PKI) inklusive Root-CA, Intermediate-CA, Server-/Client-Zertifikaten, CRL/OCSP-Unterstützung sowie einer Nginx-Docker-Umgebung für mTLS-Tests.

Dieses Projekt richtet sich an Entwickler, Security-Engineers, Studierende und alle, die eine reproduzierbare, einfach aufzubauende PKI-Umgebung für Tests, Trainings oder Zero-Trust-Szenarien benötigen.

---

## 🚀 Funktionsumfang

- Vollautomatisierte Erstellung einer **Root-CA** und **Intermediate-CA**
- Generierung von **Server- und Client-Zertifikaten**
- Automatisches CRL-Management (Revocation + CRL-Dateien)
- Lokaler **OCSP-Responder** für Echtzeit-Statusprüfungen
- **Docker + Nginx-Konfiguration** für TLS & mTLS
- Saubere Ordnerstruktur & klar trennbare Konfigurationsdateien
- Plattformneutral – verwendbar unter macOS, Linux & Windows (WSL)

---

## Funktionierende Betriebsysteme
- Ubuntu Linux ☑️
- MacOS ☑️
- Windows ❌ (In bearbeitung)

## 📁 Projektstruktur

```

OpenSSL-PKI-Docker-Automation/
├─ macOS/
│    └─ setup_instructions.md
├─ linux/
│    └─ setup_instructions.md
├─ windows/
│    └─ setup_instructions.md
├─ scripts/
├─ docker/
├─ config/
├─ pki/
└─ README.md   ← (diese Datei)

```

---

## 📘 Installations– & Setup-Anleitungen

👉 **Die vollständigen, schrittweisen Installationsanleitungen befinden sich in den jeweiligen Plattformordnern:**

- **macOS:** `macOS/setup_instructions.md`  
- **Linux:** `linux/setup_instructions.md`  
- **Windows / WSL:** `windows/setup_instructions.md`

Dort findest du:

- Vorbereitung des Systems  
- Installation der benötigten Tools  
- Ausführung des Automatisierungs-Skripts  
- Starten von OCSP, CRL-Handling, Revocation  
- Starten der Nginx-Docker-Umgebung  
- Troubleshooting  

Jede Anleitung ist speziell auf das jeweilige Betriebssystem angepasst.

---

## 🐳 Docker / mTLS Demo

Das Projekt enthält eine vollständige Docker-Konfiguration (Nginx), um:

- TLS zu testen  
- Client Certificate Authentication (mTLS) auszuprobieren  
- CRL-basierte Revocation zu testen  
- OCSP-Abfragen durchzuführen  

Sobald die PKI erzeugt wurde, kann der Nginx-Container automatisiert starten und die Zertifikate nutzen.

---

## 🎓 Anwendungsfälle

- PKI-Training & Unterricht (z. B. HTL, FH, Uni)
- Sicherheitsschulungen (OCSP, CRL, mTLS)
- DevOps- und Infrastruktur-Tests
- Zero-Trust-Architektur-Demonstrationen
- Testumgebungen für Client-Authentifizierung
- Zertifikatsmanagement lernen und automatisieren

---

## 🧰 Troubleshooting (Kurzfassung)

- Fehler „variable has no value“ → Env-Variablen für CRL & OCSP setzen  
- OCSP liefert HTML → falscher Port (443 statt 2560)  
- Datei nicht gefunden → falsches Working Directory  
- Docker startet nicht → Zertifikate korrekt gemountet?

Die detaillierten Lösungen stehen ebenfalls in den jeweiligen OS-Anleitungen.

---

## 🤝 Mitwirken

Pull Requests, Verbesserungen oder Erweiterungen sind willkommen.  
Wenn du die PKI für andere Plattformen oder zusätzliche Tools erweitern möchtest, feel free!

---

## 📜 Lizenz

MIT License – frei nutzbar für Ausbildung, Entwicklung & Testumgebungen.

```

---
