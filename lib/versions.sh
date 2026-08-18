#!/bin/bash
# Versions centralisées — modifier ici pour mettre à jour tous les environnements
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
NVM_VERSION="v0.40.3"
PYTHON_VERSION="3.13.3"
GO_VERSION="1.23.5"

# PyTorch — indices selon le backend GPU
TORCH_CUDA_INDEX="https://download.pytorch.org/whl/cu124"
TORCH_ROCM_INDEX="https://download.pytorch.org/whl/rocm6.2"
TORCH_CPU_INDEX="https://download.pytorch.org/whl/cpu"
