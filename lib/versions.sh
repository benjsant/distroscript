#!/bin/bash
# Versions centralisées : modifier ici pour mettre à jour tous les environnements
#
# Fichier de configuration : les variables sont consommées par les scripts qui
# le sourcent, pas ici. SC2034 (« appears unused ») ne s'applique donc pas.
# shellcheck disable=SC2034

UBUNTU_IMAGE="quay.io/toolbx/ubuntu-toolbox:24.04"
FEDORA_IMAGE="quay.io/fedora/fedora-toolbox:44"
# Image gaming prête à l'emploi maintenue par Universal Blue (ex-bazzite-arch).
# ~11 Go : contient déjà Steam, Lutris, Wine, MangoHud/vkBasalt (+ lib32),
# protontricks, steamcmd, la pile audio PipeWire 32 bits et les couches Vulkan.
STEAMBOX_IMAGE="ghcr.io/ublue-os/steambox"
NVM_VERSION="v0.40.7"
# Version MINEURE, pas un patch complet : uv résout vers le dernier patch qu'il
# publie. Épingler "3.14.7" échouait, python-build-standalone n'allant pas
# au-delà de 3.14.3 : les releases CPython et les builds uv ne sont pas
# synchronisées.
PYTHON_VERSION="3.14"
GO_VERSION="1.26.6"

# ubuntu_dev_ia : version mineure maximale de Python acceptée pour le venv
# PyTorch. Distincte de PYTHON_VERSION car PyTorch ne publie pas de wheels pour
# les toutes dernières versions de Python : au-delà, torch se compile depuis les
# sources ou ne s'installe pas. À relever quand PyTorch suit.
IA_PYTHON_MAX_MINOR="13"

# ubuntu_dev_dotnet : SDK .NET. Ubuntu 24.04 fournit lui-même dotnet-sdk-10.0
# dans noble-updates/main, le dépôt Microsoft n'est donc plus nécessaire pour
# le SDK (il reste utilisé pour PowerShell).
DOTNET_SDK_VERSION="10.0"

# ubuntu_dev_java : identifiants SDKMAN des deux LTS installées. Vérifiés
# contre la liste réelle de SDKMAN, dont les identifiants diffèrent du semver
# publié par Adoptium.
JDK_LTS="25.0.4-tem"
JDK_PREV_LTS="21.0.12-tem"

# Versions de repli des outils résolus via l'API GitHub.
# Utilisées quand l'API est indisponible (limite de 60 requêtes/h et par IP) :
# voir github_latest_tag() dans lib/fetch.sh. À rafraîchir de temps en temps.
K9S_FALLBACK="v0.51.0"
KIND_FALLBACK="v0.32.0"
COSIGN_FALLBACK="v3.1.3"
GITLEAKS_FALLBACK="v8.30.1"
VALE_FALLBACK="v3.17.1"
DUCKDB_FALLBACK="v1.5.5"
EISVOGEL_FALLBACK="v3.5.1"

# PyTorch : indices selon le backend GPU
TORCH_CUDA_INDEX="https://download.pytorch.org/whl/cu124"
TORCH_ROCM_INDEX="https://download.pytorch.org/whl/rocm6.4"
TORCH_CPU_INDEX="https://download.pytorch.org/whl/cpu"
