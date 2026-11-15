#!/bin/bash
set -euo pipefail

# ==============================================================================
# VIRGOZKI SSH-WS DEPLOYER v3.1 (ALL REGIONS - SAFE MODE)
# ==============================================================================

BOLD='\033[1m'
RESET='\033[0m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
MAGENTA='\033[1;35m'
PINK='\033[38;5;201m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
WHITE='\033[1;97m'

clear 2>/dev/null || true
echo -e "${CYAN}"
cat <<'BANNER'
+==============================================================+
|                    VIRGOZKI SSH-WS                           |
|              DEPLOYER v3.1 (ALL REGIONS)                     |
+==============================================================+
BANNER
echo -e "${RESET}"

PROJECT_ID="$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
    echo -e "${RED}ERROR:${RESET} No active GCP project."
    echo "Run: gcloud init"
    exit 1
fi

echo -e "${GREEN}PROJECT:${RESET} ${CYAN}${PROJECT_ID}${RESET}"
echo

echo -e "${CYAN}[1/5] Enabling required Google Cloud APIs...${RESET}"
gcloud services enable \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com \
    --project="${PROJECT_ID}"

echo
echo -e "${MAGENTA}==============================================================${RESET}"
echo -e "${GREEN}                     SERVICE NAME${RESET}"
echo -e "${MAGENTA}==============================================================${RESET}"
read -r -p "Service name [virgozki]: " INPUT_NAME
SERVICE_NAME="${INPUT_NAME:-virgozki}"
SERVICE_NAME="$(echo "${SERVICE_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/^-*//; s/-*$//' | cut -c1-49)"
[[ -n "${SERVICE_NAME}" ]] || SERVICE_NAME="virgozki"

echo
echo -e "${MAGENTA}==============================================================${RESET}"
echo -e "${GREEN}                        REGION${RESET}"
echo -e "${MAGENTA}==============================================================${RESET}"
echo -e "${YELLOW}--- ASIA ---${RESET}"
echo "  1) asia-east1        (Taiwan)"
echo "  2) asia-east2        (Hong Kong)"
echo "  3) asia-northeast1   (Tokyo, Japan)"
echo "  4) asia-northeast2   (Osaka, Japan)"
echo "  5) asia-northeast3   (Seoul, South Korea)"
echo "  6) asia-south1       (Mumbai, India)"
echo "  7) asia-south2       (Delhi, India)"
echo "  8) asia-southeast1   (Singapore)"
echo "  9) asia-southeast2   (Jakarta, Indonesia)"
echo
echo -e "${YELLOW}--- UNITED STATES ---${RESET}"
echo "  10) us-central1      (Iowa)"
echo "  11) us-east1         (South Carolina)"
echo "  12) us-east4         (Northern Virginia)"
echo "  13) us-east5         (Columbus)"
echo "  14) us-south1        (Dallas)"
echo "  15) us-west1         (Oregon)"
echo "  16) us-west2         (Los Angeles)"
echo "  17) us-west3         (Salt Lake City)"
echo "  18) us-west4         (Las Vegas)"
echo
echo -e "${YELLOW}--- EUROPE ---${RESET}"
echo "  19) europe-central2  (Warsaw, Poland)"
echo "  20) europe-north1    (Finland)"
echo "  21) europe-west1     (Belgium)"
echo "  22) europe-west2     (London, UK)"
echo "  23) europe-west3     (Frankfurt, Germany)"
echo "  24) europe-west4     (Eemshaven, Netherlands)"
echo "  25) europe-west9     (Paris, France)"
echo
echo -e "${YELLOW}--- OTHERS ---${RESET}"
echo "  26) northamerica-northeast1 (Montréal, Canada)"
echo "  27) southamerica-east1      (São Paulo, Brazil)"
echo "  28) australia-southeast1    (Sydney, Australia)"
echo

read -r -p "Choose region [1-28] (default 8 - Singapore): " REGION_CHOICE

case "${REGION_CHOICE:-8}" in
    1) REGION="asia-east1" ;;
    2) REGION="asia-east2" ;;
    3) REGION="asia-northeast1" ;;
    4) REGION="asia-northeast2" ;;
    5) REGION="asia-northeast3" ;;
    6) REGION="asia-south1" ;;
    7) REGION="asia-south2" ;;
    8) REGION="asia-southeast1" ;;
    9) REGION="asia-southeast2" ;;
    10) REGION="us-central1" ;;
    11) REGION="us-east1" ;;
    12) REGION="us-east4" ;;
    13) REGION="us-east5" ;;
    14) REGION="us-south1" ;;
    15) REGION="us-west1" ;;
    16) REGION="us-west2" ;;
    17) REGION="us-west3" ;;
    18) REGION="us-west4" ;;
    19) REGION="europe-central2" ;;
    20) REGION="europe-north1" ;;
    21) REGION="europe-west1" ;;
    22) REGION="europe-west2" ;;
    23) REGION="europe-west3" ;;
    24) REGION="europe-west4" ;;
    25) REGION="europe-west9" ;;
    26) REGION="northamerica-northeast1" ;;
    27) REGION="southamerica-east1" ;;
    28) REGION="australia-southeast1" ;;
    *) REGION="asia-southeast1" ;;
esac

echo -e "${GREEN}Selected Region:${RESET} ${CYAN}${REGION}${RESET}"
echo

# Safe Resource Profile para iwas-suspension (Low/Standard)
CPU="1"
RAM="512Mi"
MAX_INSTANCES="2"
MIN_INSTANCES="0"
CONCURRENCY="80"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/virgozki-build-${SERVICE_NAME}"
mkdir -p "${BUILD_DIR}"

echo -e "${PINK}[2/5] Preparing separated build files...${RESET}"
cp "${SCRIPT_DIR}/Dockerfile" "${BUILD_DIR}/Dockerfile"
cp "${SCRIPT_DIR}/entrypoint.sh" "${BUILD_DIR}/entrypoint.sh"
cp "${SCRIPT_DIR}/nginx.conf" "${BUILD_DIR}/nginx.conf"
cp "${SCRIPT_DIR}/banner.txt" "${BUILD_DIR}/banner.txt"
chmod +x "${BUILD_DIR}/entrypoint.sh"

REPOSITORY="virgozki-docker"

echo -e "${PINK}[3/5] Preparing Artifact Registry in ${REGION}...${RESET}"
if ! gcloud artifacts repositories describe "${REPOSITORY}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" >/dev/null 2>&1; then

    gcloud artifacts repositories create "${REPOSITORY}" \
        --repository-format=docker \
        --location="${REGION}" \
        --description="Virgozki Docker images" \
        --project="${PROJECT_ID}"
fi

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${SERVICE_NAME}:latest"

echo -e "${PINK}[4/5] Building image...${RESET}"
gcloud builds submit "${BUILD_DIR}" \
    --ignore-file=/dev/null \
    --tag "${IMAGE}" \
    --project="${PROJECT_ID}"

echo -e "${PINK}[5/5] Deploying Cloud Run service...${RESET}"
gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE}" \
    --platform managed \
    --region "${REGION}" \
    --port 8080 \
    --allow-unauthenticated \
    --project="${PROJECT_ID}" \
    --cpu "${CPU}" \
    --memory "${RAM}" \
    --min-instances "${MIN_INSTANCES}" \
    --max-instances "${MAX_INSTANCES}" \
    --concurrency "${CONCURRENCY}" \
    --timeout 3600 \
    --execution-environment gen2

SERVICE_URL="$(gcloud run services describe "${SERVICE_NAME}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --format='value(status.url)' 2>/dev/null || true)"

CLEAN_HOST="${SERVICE_URL#https://}"

echo -e "${GREEN}+==============================================================+${RESET}"
echo -e "${GREEN}|                 VIRGOZKI SSH-WS READY                       |${RESET}"
echo -e "${GREEN}+==============================================================+${RESET}"
echo -e "${CYAN}SERVICE      :${RESET} ${SERVICE_NAME}"
echo -e "${CYAN}REGION       :${RESET} ${REGION}"
echo -e "${CYAN}URL          :${RESET} ${SERVICE_URL}"
echo -e "${CYAN}WS PATH      :${RESET} /virgozki"
echo
echo -e "${YELLOW}ENDPOINT:${RESET}"
echo -e "${GREEN}${SERVICE_URL}/virgozki${RESET}"
