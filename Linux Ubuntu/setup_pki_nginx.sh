#!/usr/bin/env bash
set -euo pipefail

##############################################
#
#  Auto-PKI + Docker/Nginx Setup Script (Linux/Ubuntu)
#  Made by 0xWunda
#  https://github.com/0xWunda/OPENSSL-PKI-DOCKER-AUTOMATION
#
##############################################


##############################################
# Docker & Docker Compose Installation (Ubuntu/Debian)
##############################################

install_docker() {
  echo ">>> Prüfe, ob Docker installiert ist..."

  if command -v docker >/dev/null 2>&1; then
    echo ">>> Docker ist bereits installiert."
    return
  fi

  echo ">>> Docker nicht gefunden. Installiere Docker..."

  # Alte Versionen entfernen
  sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  # Paketquellen aktualisieren
  sudo apt-get update -y

  # benötigte Pakete installieren
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  # Docker GPG Key
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Docker Repo hinzufügen
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Docker installieren
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Docker-Dienst starten + aktivieren
  sudo systemctl enable docker
  sudo systemctl start docker

  echo ">>> Docker erfolgreich installiert!"
}

# Installation ausführen
install_docker

# --- OpenSSL finden ---
if command -v openssl >/dev/null 2>&1; then
  OPENSSL_BIN="$(command -v openssl)"
else
  echo "Fehler: OpenSSL wurde nicht gefunden. Installiere es mit:"
  echo "  sudo apt install openssl"
  exit 1
fi

echo "Verwende OpenSSL: $OPENSSL_BIN"

# --- Basis-Pfade ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$BASE_DIR/config"
PKI_DIR="$BASE_DIR/pki"
DOCKER_DIR="$BASE_DIR/docker"

mkdir -p "$CONFIG_DIR" "$PKI_DIR" "$DOCKER_DIR"

##############################################
# 1) pki-vars.conf anlegen (wenn nicht existiert)
##############################################
VARS_FILE="$CONFIG_DIR/pki-vars.conf"

if [[ ! -f "$VARS_FILE" ]]; then
  cat >"$VARS_FILE" <<'EOF'
# PKI Default-Variablen (kannst du nach Bedarf anpassen)

COUNTRY="AT"
STATE="Steiermark"
LOCALITY="Graz"
ORG="0xWunda HQ"
ORG_UNIT="IT"

ROOT_CN="0xWunda Root CA"
INT_CN="0xWunda Intermediate CA"
SERVER_CN="0xWunda.local"
CLIENT_CN="0xWunda Client"

# CRL / OCSP URLs (für AIA/CDP-Felder)
CRL_URL="http://localhost:8080/crl/intermediate.crl.pem"
OCSP_URL="http://localhost:2560"
EOF

  echo "Config-Datei erstellt: $VARS_FILE"
else
  echo "Config-Datei bereits vorhanden: $VARS_FILE (wird verwendet)"
fi

source "$VARS_FILE"

##############################################
# 2) OpenSSL-Konfigurationsdateien schreiben
##############################################

ROOT_CNF="$CONFIG_DIR/openssl-root.cnf"
INT_CNF="$CONFIG_DIR/openssl-intermediate.cnf"

cat >"$ROOT_CNF" <<'EOF'
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = ./pki/root
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
crlnumber         = $dir/crlnumber

certificate       = $dir/certs/ca.cert.pem
private_key       = $dir/private/ca.key.pem
crl               = $dir/crl/ca.crl.pem

default_days      = 3650
default_crl_days  = 365
default_md        = sha256
preserve          = no
policy            = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name

[ v3_ca ]
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, keyCertSign, cRLSign

[ v3_intermediate_ca ]
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true, pathlen:0
keyUsage                = critical, keyCertSign, cRLSign
crlDistributionPoints   = URI:$ENV::CRL_URL
authorityInfoAccess     = OCSP;URI:$ENV::OCSP_URL

[ crl_ext ]
authorityKeyIdentifier  = keyid:always
EOF

cat >"$INT_CNF" <<'EOF'
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = ./pki/intermediate
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
crlnumber         = $dir/crlnumber

certificate       = $dir/certs/intermediate.cert.pem
private_key       = $dir/private/intermediate.key.pem
crl               = $dir/crl/intermediate.crl.pem

default_days      = 1825
default_crl_days  = 30
default_md        = sha256
preserve          = no
policy            = policy_loose

[ policy_loose ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name

[ v3_intermediate_ca ]
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true, pathlen:0
keyUsage                = critical, CA:true, keyCertSign, cRLSign
crlDistributionPoints   = URI:$ENV::CRL_URL
authorityInfoAccess     = OCSP;URI:$ENV::OCSP_URL

[ server_cert ]
basicConstraints        = CA:false
nsCertType              = server
nsComment               = "Server Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth
crlDistributionPoints   = URI:$ENV::CRL_URL
authorityInfoAccess     = OCSP;URI:$ENV::OCSP_URL

[ usr_cert ]
basicConstraints        = CA:false
nsCertType              = client, email
nsComment               = "Client Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = clientAuth, emailProtection
crlDistributionPoints   = URI:$ENV::CRL_URL
authorityInfoAccess     = OCSP;URI:$ENV::OCSP_URL

[ crl_ext ]
authorityKeyIdentifier  = keyid:always

[ ocsp ]
basicConstraints        = CA:false
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = critical, digitalSignature
extendedKeyUsage        = critical, OCSPSigning
EOF

echo "OpenSSL-Konfigurationen erstellt/aktualisiert."

##############################################
# 3) PKI-Verzeichnisstruktur anlegen
##############################################

cd "$BASE_DIR"

mkdir -p "$PKI_DIR/root/"{certs,crl,newcerts,private}
mkdir -p "$PKI_DIR/intermediate/"{certs,crl,newcerts,private,csr}
mkdir -p "$PKI_DIR/server/"{certs,private,csr}
mkdir -p "$PKI_DIR/client/"{certs,private,csr}

chmod 700 "$PKI_DIR"/root/private "$PKI_DIR"/intermediate/private

# Root DB-Dateien
[[ -f "$PKI_DIR/root/index.txt" ]] || touch "$PKI_DIR/root/index.txt"
[[ -f "$PKI_DIR/root/serial" ]] || echo 1000 > "$PKI_DIR/root/serial"
[[ -f "$PKI_DIR/root/crlnumber" ]] || echo 1000 > "$PKI_DIR/root/crlnumber"

# Intermediate DB-Dateien
[[ -f "$PKI_DIR/intermediate/index.txt" ]] || touch "$PKI_DIR/intermediate/index.txt"
[[ -f "$PKI_DIR/intermediate/serial" ]] || echo 2000 > "$PKI_DIR/intermediate/serial"
[[ -f "$PKI_DIR/intermediate/crlnumber" ]] || echo 2000 > "$PKI_DIR/intermediate/crlnumber"

# Konfigs an Zielort kopieren
cp "$ROOT_CNF" "$PKI_DIR/root/openssl.cnf"
cp "$INT_CNF"  "$PKI_DIR/intermediate/openssl.cnf"

##############################################
# 4) Optional: Interaktive Eingabe der DN-Werte
##############################################

echo
echo "=== PKI Setup ==="
echo "Standardwerte stehen in: $VARS_FILE"
read -rp "Werte aus Config verwenden (1) oder interaktiv anpassen (2)? [1]: " MODE
MODE="${MODE:-1}"

if [[ "$MODE" == "2" ]]; then
  read -rp "Country (2 Buchstaben) [$COUNTRY]: " TMP && COUNTRY="${TMP:-$COUNTRY}"
  read -rp "State [$STATE]: " TMP && STATE="${TMP:-$STATE}"
  read -rp "Locality [$LOCALITY]: " TMP && LOCALITY="${TMP:-$LOCALITY}"
  read -rp "Org [$ORG]: " TMP && ORG="${TMP:-$ORG}"
  read -rp "Org Unit [$ORG_UNIT]: " TMP && ORG_UNIT="${TMP:-$ORG_UNIT}"
  read -rp "Root CN [$ROOT_CN]: " TMP && ROOT_CN="${TMP:-$ROOT_CN}"
  read -rp "Intermediate CN [$INT_CN]: " TMP && INT_CN="${TMP:-$INT_CN}"
  read -rp "Server CN [$SERVER_CN]: " TMP && SERVER_CN="${TMP:-$SERVER_CN}"
  read -rp "Client CN [$CLIENT_CN]: " TMP && CLIENT_CN="${TMP:-$CLIENT_CN}"
fi

SUBJ_ROOT="/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$ROOT_CN"
SUBJ_INT="/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$INT_CN"
SUBJ_SERVER="/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$SERVER_CN"
SUBJ_CLIENT="/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$CLIENT_CN"

export CRL_URL OCSP_URL

##############################################
# 5) Root-CA erzeugen
##############################################

echo
echo "=== Root-CA erstellen ==="

if [[ ! -f "$PKI_DIR/root/private/ca.key.pem" ]]; then
  "$OPENSSL_BIN" genrsa -out "$PKI_DIR/root/private/ca.key.pem" 4096
  chmod 400 "$PKI_DIR/root/private/ca.key.pem"
fi

if [[ ! -f "$PKI_DIR/root/certs/ca.cert.pem" ]]; then
  "$OPENSSL_BIN" req -config "$PKI_DIR/root/openssl.cnf" \
    -key "$PKI_DIR/root/private/ca.key.pem" \
    -new -x509 -days 3650 -sha256 \
    -extensions v3_ca \
    -subj "$SUBJ_ROOT" \
    -out "$PKI_DIR/root/certs/ca.cert.pem"
  chmod 444 "$PKI_DIR/root/certs/ca.cert.pem"
fi

##############################################
# 6) Intermediate-CA erzeugen
##############################################

echo
echo "=== Intermediate-CA erstellen ==="

if [[ ! -f "$PKI_DIR/intermediate/private/intermediate.key.pem" ]]; then
  "$OPENSSL_BIN" genrsa -out "$PKI_DIR/intermediate/private/intermediate.key.pem" 4096
  chmod 400 "$PKI_DIR/intermediate/private/intermediate.key.pem"
fi

"$OPENSSL_BIN" req -config "$PKI_DIR/intermediate/openssl.cnf" \
  -key "$PKI_DIR/intermediate/private/intermediate.key.pem" \
  -new -sha256 \
  -subj "$SUBJ_INT" \
  -out "$PKI_DIR/intermediate/csr/intermediate.csr.pem"

if [[ ! -f "$PKI_DIR/intermediate/certs/intermediate.cert.pem" ]]; then
  "$OPENSSL_BIN" ca -config "$PKI_DIR/root/openssl.cnf" \
    -extensions v3_intermediate_ca \
    -days 3650 -notext -md sha256 \
    -in "$PKI_DIR/intermediate/csr/intermediate.csr.pem" \
    -out "$PKI_DIR/intermediate/certs/intermediate.cert.pem" -batch
  chmod 444 "$PKI_DIR/intermediate/certs/intermediate.cert.pem"
fi

cat "$PKI_DIR/intermediate/certs/intermediate.cert.pem" \
    "$PKI_DIR/root/certs/ca.cert.pem" \
  > "$PKI_DIR/intermediate/certs/ca-chain.cert.pem"
chmod 444 "$PKI_DIR/intermediate/certs/ca-chain.cert.pem"

"$OPENSSL_BIN" ca -config "$PKI_DIR/intermediate/openssl.cnf" \
  -gencrl -out "$PKI_DIR/intermediate/crl/intermediate.crl.pem"

##############################################
# 7) Server- und Client-Zertifikat erstellen
##############################################

echo
echo "=== Server- & Client-Zertifikate erstellen ==="

# Server
if [[ ! -f "$PKI_DIR/server/private/server.key.pem" ]]; then
  "$OPENSSL_BIN" genrsa -out "$PKI_DIR/server/private/server.key.pem" 2048
  chmod 400 "$PKI_DIR/server/private/server.key.pem"
fi

"$OPENSSL_BIN" req -config "$PKI_DIR/intermediate/openssl.cnf" \
  -key "$PKI_DIR/server/private/server.key.pem" \
  -new -sha256 \
  -subj "$SUBJ_SERVER" \
  -out "$PKI_DIR/server/csr/server.csr.pem"

"$OPENSSL_BIN" ca -config "$PKI_DIR/intermediate/openssl.cnf" \
  -extensions server_cert -days 825 -notext -md sha256 \
  -in "$PKI_DIR/server/csr/server.csr.pem" \
  -out "$PKI_DIR/server/certs/server.cert.pem" -batch
chmod 444 "$PKI_DIR/server/certs/server.cert.pem"

# Client
if [[ ! -f "$PKI_DIR/client/private/client.key.pem" ]]; then
  "$OPENSSL_BIN" genrsa -out "$PKI_DIR/client/private/client.key.pem" 2048
  chmod 400 "$PKI_DIR/client/private/client.key.pem"
fi

"$OPENSSL_BIN" req -config "$PKI_DIR/intermediate/openssl.cnf" \
  -key "$PKI_DIR/client/private/client.key.pem" \
  -new -sha256 \
  -subj "$SUBJ_CLIENT" \
  -out "$PKI_DIR/client/csr/client.csr.pem"

"$OPENSSL_BIN" ca -config "$PKI_DIR/intermediate/openssl.cnf" \
  -extensions usr_cert -days 825 -notext -md sha256 \
  -in "$PKI_DIR/client/csr/client.csr.pem" \
  -out "$PKI_DIR/client/certs/client.cert.pem" -batch
chmod 444 "$PKI_DIR/client/certs/client.cert.pem"

##############################################
# 8) Docker / Nginx Dateien erzeugen
##############################################

echo
echo "=== Docker / Nginx Dateien erzeugen ==="

NGINX_CONF="$DOCKER_DIR/nginx.conf"
DOCKERFILE="$DOCKER_DIR/Dockerfile"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

cat >"$NGINX_CONF" <<'EOF'
worker_processes  1;

events {
    worker_connections 1024;
}

http {
    server {
        listen              443 ssl;
        server_name         nginx.local;

        ssl_certificate     /etc/nginx/certs/server.cert.pem;
        ssl_certificate_key /etc/nginx/private/server.key.pem;

        ssl_client_certificate /etc/nginx/certs/ca-chain.cert.pem;
        ssl_verify_client optional;
        ssl_verify_depth 2;

        ssl_crl /etc/nginx/crl/intermediate.crl.pem;

        ssl_stapling on;
        ssl_stapling_verify on;
        resolver 1.1.1.1 8.8.8.8 valid=300s;
        resolver_timeout 5s;

        location / {
            return 200 "Hello from Nginx with mTLS + CRL!\n";
        }
    }
}
EOF

cat >"$DOCKERFILE" <<'EOF'
FROM nginx:alpine

RUN mkdir -p /etc/nginx/certs /etc/nginx/private /etc/nginx/crl

COPY nginx.conf /etc/nginx/nginx.conf
EOF

cat >"$COMPOSE_FILE" <<'EOF'
version: "3.8"

services:
  nginx:
    build: .
    container_name: pki-nginx
    ports:
      - "443:443"
    volumes:
      - ../pki/server/certs/server.cert.pem:/etc/nginx/certs/server.cert.pem:ro
      - ../pki/server/private/server.key.pem:/etc/nginx/private/server.key.pem:ro
      - ../pki/intermediate/certs/ca-chain.cert.pem:/etc/nginx/certs/ca-chain.cert.pem:ro
      - ../pki/intermediate/crl/intermediate.crl.pem:/etc/nginx/crl/intermediate.crl.pem:ro
EOF

##############################################
# 9) Kurze Zusammenfassung
##############################################

echo
echo "=== FERTIG ==="
echo "Projektordner: $BASE_DIR"
echo
echo "Wichtige Dateien:"
echo "  Root-CA:        $PKI_DIR/root/certs/ca.cert.pem"
echo "  Intermediate-CA:$PKI_DIR/intermediate/certs/intermediate.cert.pem"
echo "  CA-Chain:       $PKI_DIR/intermediate/certs/ca-chain.cert.pem"
echo "  Server-Cert:    $PKI_DIR/server/certs/server.cert.pem"
echo "  Client-Cert:    $PKI_DIR/client/certs/client.cert.pem"
echo "  CRL:            $PKI_DIR/intermediate/crl/intermediate.crl.pem"
echo
echo "Docker/Nginx:"
echo "  $DOCKER_DIR/nginx.conf"
echo "  $DOCKER_DIR/Dockerfile"
echo "  $DOCKER_DIR/docker-compose.yml"
echo
echo "Nginx starten (im docker-Verzeichnis):"
echo "  cd \"$DOCKER_DIR\""
echo "  docker-compose up --build"
echo
echo "OCSP-Responder starten:"
echo "  $OPENSSL_BIN ocsp -port 127.0.0.1:2560 -index \"$PKI_DIR/intermediate/index.txt\" \\"
echo "    -CA \"$PKI_DIR/intermediate/certs/ca-chain.cert.pem\" \\"
echo "    -rkey \"$PKI_DIR/intermediate/private/intermediate.key.pem\" \\"
echo "    -rsigner \"$PKI_DIR/intermediate/certs/intermediate.cert.pem\" -text"
echo
echo "Zertifikat revoken + CRL neu erzeugen:"
echo "  $OPENSSL_BIN ca -config \"$PKI_DIR/intermediate/openssl.cnf\" -revoke <ZERT.PEM>"
echo "  $OPENSSL_BIN ca -config \"$PKI_DIR/intermediate/openssl.cnf\" -gencrl -out \"$PKI_DIR/intermediate/crl/intermediate.crl.pem\""
echo
echo "Fertig 🎉"
