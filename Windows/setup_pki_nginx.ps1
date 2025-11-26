Param(
    [string]$ProjectRoot = $(Get-Location).Path,
    [string]$OpenSslPath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"
)

# ------------------------------
# Helper: OpenSSL-Binary finden
# ------------------------------
if (-not (Test-Path $OpenSslPath)) {
    if (Get-Command "openssl" -ErrorAction SilentlyContinue) {
        $OpenSslPath = (Get-Command openssl).Source
    } else {
        Write-Error "OpenSSL wurde nicht gefunden. Bitte Pfad in OpenSslPath anpassen oder openssl in PATH installieren."
        exit 1
    }
}

Write-Host "Verwende OpenSSL: $OpenSslPath"

# ------------------------------
# Basis-Pfade
# ------------------------------
$ConfigDir = Join-Path $ProjectRoot "config"
$PkiDir    = Join-Path $ProjectRoot "pki"
$DockerDir = Join-Path $ProjectRoot "docker"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $PkiDir    | Out-Null
New-Item -ItemType Directory -Force -Path $DockerDir | Out-Null

# ------------------------------
# PKI-Variablen (kannst du hier anpassen)
# ------------------------------
$COUNTRY   = "AT"
$STATE     = "Niederösterreich"
$LOCALITY  = "Ybbs an der Donau"
$ORG       = "LoRaSense Demo"
$ORG_UNIT  = "IT"

$ROOT_CN   = "LoRaSense Root CA"
$INT_CN    = "LoRaSense Intermediate CA"
$SERVER_CN = "nginx.local"
$CLIENT_CN = "LoRaSense Client"

$CRL_URL   = "http://localhost:8080/crl/intermediate.crl.pem"
$OCSP_URL  = "http://127.0.0.1:2560"

# Env-Variablen für OpenSSL-$ENV:: verwenden
$env:CRL_URL  = $CRL_URL
$env:OCSP_URL = $OCSP_URL

# ------------------------------
# OpenSSL-Konfigurationsdateien
# ------------------------------
$RootCnfPath = Join-Path $ConfigDir "openssl-root.cnf"
$IntCnfPath  = Join-Path $ConfigDir "openssl-intermediate.cnf"

@"
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
keyUsage                = critical, CA:true, keyCertSign, cRLSign
crlDistributionPoints   = URI:$ENV::CRL_URL
authorityInfoAccess     = OCSP;URI:$ENV::OCSP_URL

[ crl_ext ]
authorityKeyIdentifier  = keyid:always
"@ | Set-Content -Path $RootCnfPath -Encoding ASCII

@"
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
"@ | Set-Content -Path $IntCnfPath -Encoding ASCII

Write-Host "OpenSSL-Konfigurationen erstellt."

# ------------------------------
# PKI-Verzeichnisstruktur
# ------------------------------
$RootDir = Join-Path $PkiDir "root"
$IntDir  = Join-Path $PkiDir "intermediate"
$SrvDir  = Join-Path $PkiDir "server"
$CliDir  = Join-Path $PkiDir "client"

$dirsToCreate = @(
    (Join-Path $RootDir "certs"),
    (Join-Path $RootDir "crl"),
    (Join-Path $RootDir "newcerts"),
    (Join-Path $RootDir "private"),
    (Join-Path $IntDir  "certs"),
    (Join-Path $IntDir  "crl"),
    (Join-Path $IntDir  "newcerts"),
    (Join-Path $IntDir  "private"),
    (Join-Path $IntDir  "csr"),
    (Join-Path $SrvDir  "certs"),
    (Join-Path $SrvDir  "private"),
    (Join-Path $SrvDir  "csr"),
    (Join-Path $CliDir  "certs"),
    (Join-Path $CliDir  "private"),
    (Join-Path $CliDir  "csr")
)

foreach ($d in $dirsToCreate) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

# DB-Dateien
$rootIndex = Join-Path $RootDir "index.txt"
$rootSerial = Join-Path $RootDir "serial"
$rootCrlNum = Join-Path $RootDir "crlnumber"

$intIndex = Join-Path $IntDir "index.txt"
$intSerial = Join-Path $IntDir "serial"
$intCrlNum = Join-Path $IntDir "crlnumber"

if (-not (Test-Path $rootIndex))  { New-Item $rootIndex -ItemType File | Out-Null }
if (-not (Test-Path $rootSerial)) { "1000" | Set-Content $rootSerial }
if (-not (Test-Path $rootCrlNum)) { "1000" | Set-Content $rootCrlNum }

if (-not (Test-Path $intIndex))   { New-Item $intIndex -ItemType File | Out-Null }
if (-not (Test-Path $intSerial))  { "2000" | Set-Content $intSerial }
if (-not (Test-Path $intCrlNum))  { "2000" | Set-Content $intCrlNum }

Copy-Item $RootCnfPath (Join-Path $RootDir "openssl.cnf") -Force
Copy-Item $IntCnfPath  (Join-Path $IntDir  "openssl.cnf") -Force

# ------------------------------
# DN zusammenbauen
# ------------------------------
$SubjRoot   = "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$ROOT_CN"
$SubjInt    = "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$INT_CN"
$SubjServer = "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$SERVER_CN"
$SubjClient = "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$CLIENT_CN"

Write-Host "=== Erstelle Root-CA ==="

$RootKey  = Join-Path $RootDir "private\ca.key.pem"
$RootCert = Join-Path $RootDir "certs\ca.cert.pem"
$RootCnf  = Join-Path $RootDir "openssl.cnf"

if (-not (Test-Path $RootKey)) {
    & $OpenSslPath genrsa -out $RootKey 4096
}

if (-not (Test-Path $RootCert)) {
    & $OpenSslPath req -config $RootCnf `
        -key $RootKey `
        -new -x509 -days 3650 -sha256 `
        -extensions v3_ca `
        -subj $SubjRoot `
        -out $RootCert
}

Write-Host "=== Erstelle Intermediate-CA ==="

$IntKey   = Join-Path $IntDir "private\intermediate.key.pem"
$IntCsr   = Join-Path $IntDir "csr\intermediate.csr.pem"
$IntCert  = Join-Path $IntDir "certs\intermediate.cert.pem"
$IntCnf   = Join-Path $IntDir "openssl.cnf"
$ChainPem = Join-Path $IntDir "certs\ca-chain.cert.pem"
$IntCrl   = Join-Path $IntDir "crl\intermediate.crl.pem"

if (-not (Test-Path $IntKey)) {
    & $OpenSslPath genrsa -out $IntKey 4096
}

& $OpenSslPath req -config $IntCnf `
    -key $IntKey `
    -new -sha256 `
    -subj $SubjInt `
    -out $IntCsr

if (-not (Test-Path $IntCert)) {
    & $OpenSslPath ca -config $RootCnf `
        -extensions v3_intermediate_ca `
        -days 3650 -notext -md sha256 `
        -in $IntCsr `
        -out $IntCert -batch
}

# CA-Chain
Get-Content $IntCert, $RootCert | Set-Content $ChainPem

# Erste CRL
& $OpenSslPath ca -config $IntCnf `
    -gencrl -out $IntCrl

Write-Host "=== Erstelle Server- & Client-Zertifikate ==="

$SrvKey  = Join-Path $SrvDir "private\server.key.pem"
$SrvCsr  = Join-Path $SrvDir "csr\server.csr.pem"
$SrvCert = Join-Path $SrvDir "certs\server.cert.pem"

if (-not (Test-Path $SrvKey)) {
    & $OpenSslPath genrsa -out $SrvKey 2048
}

& $OpenSslPath req -config $IntCnf `
    -key $SrvKey `
    -new -sha256 `
    -subj $SubjServer `
    -out $SrvCsr

& $OpenSslPath ca -config $IntCnf `
    -extensions server_cert -days 825 -notext -md sha256 `
    -in $SrvCsr `
    -out $SrvCert -batch

$CliKey  = Join-Path $CliDir "private\client.key.pem"
$CliCsr  = Join-Path $CliDir "csr\client.csr.pem"
$CliCert = Join-Path $CliDir "certs\client.cert.pem"

if (-not (Test-Path $CliKey)) {
    & $OpenSslPath genrsa -out $CliKey 2048
}

& $OpenSslPath req -config $IntCnf `
    -key $CliKey `
    -new -sha256 `
    -subj $SubjClient `
    -out $CliCsr

& $OpenSslPath ca -config $IntCnf `
    -extensions usr_cert -days 825 -notext -md sha256 `
    -in $CliCsr `
    -out $CliCert -batch

Write-Host "=== Docker / Nginx Dateien erzeugen ==="

$NginxConf = Join-Path $DockerDir "nginx.conf"
$DockerfilePath = Join-Path $DockerDir "Dockerfile"
$ComposePath = Join-Path $DockerDir "docker-compose.yml"

@"
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
            return 200 "Hello from Nginx with mTLS + CRL!`n";
        }
    }
}
"@ | Set-Content -Path $NginxConf -Encoding ASCII

@"
FROM nginx:alpine

RUN mkdir -p /etc/nginx/certs /etc/nginx/private /etc/nginx/crl

COPY nginx.conf /etc/nginx/nginx.conf
"@ | Set-Content -Path $DockerfilePath -Encoding ASCII

@"
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
"@ | Set-Content -Path $ComposePath -Encoding ASCII

Write-Host ""
Write-Host "=== FERTIG ==="
Write-Host "Projektordner: $ProjectRoot"
Write-Host "Root-CA:        $RootCert"
Write-Host "Intermediate-CA:$IntCert"
Write-Host "CA-Chain:       $ChainPem"
Write-Host "Server-Zert:    $SrvCert"
Write-Host "Client-Zert:    $CliCert"
Write-Host "CRL:            $IntCrl"
Write-Host ""
Write-Host "Nginx starten (im docker-Verzeichnis):"
Write-Host "  cd `"$DockerDir`""
Write-Host "  docker compose up --build"
Write-Host ""
Write-Host "OCSP-Responder (Beispiel, manuell):"
Write-Host "  & `"$OpenSslPath`" ocsp -index `"$intIndex`" -port 2560 -CA `"$ChainPem`" -rkey `"$IntKey`" -rsigner `"$IntCert`" -text"
Write-Host ""
