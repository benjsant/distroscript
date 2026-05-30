# 📦 DistroScript

![image](featured_image.png)

**DistroScript** est un ensemble de scripts Bash permettant de créer et configurer automatiquement des environnements de développement isolés grâce à **Distrobox**.
Chaque environnement est basé sur Ubuntu 24.04 et préinstallé avec les outils nécessaires à un usage ciblé.

* * *

## 🚀 Fonctionnalités

- Création automatisée de **Distrobox** dédiées selon le besoin
- Scripts de **post-installation** pour configurer chaque environnement
- **Détection de l'hôte** (distro, moteur de conteneur, SELinux, cgroups, GPU) pour adapter les options
- **Détection GPU NVIDIA/ROCm** automatique — support activé si les pré-requis sont présents sur l'hôte
- **Détection et correction du bug de locale** (`fr_FR.utf8` non canonique) qui casse `distrobox-init` sur les images Ubuntu
- **Logs** d'installation sauvegardés dans `~/distrobox/<nom>_install.log`
- **Vérification post-install** des outils clés
- Script de **mise à jour** des environnements existants
- Script de **désinstallation** propre
- Choix interactif de l'environnement à installer

* * *

## 📋 Environnements disponibles

| # | Nom | Base | Outils principaux |
| --- | --- | --- | --- |
| 1 | `ubuntu_dev_hugo` | Ubuntu 24.04 | Hugo, Homebrew, Node (NVM), VS Code, gh |
| 2 | `ubuntu_dev_python` | Ubuntu 24.04 | pyenv, uv, Node (NVM), VS Code, gh |
| 3 | `ubuntu_dev_ia` | Ubuntu 24.04 | Ollama, pyenv, uv, PyTorch — GPU NVIDIA/ROCm/CPU |
| 4 | `ubuntu_dev_rust` | Ubuntu 24.04 | rustup, cargo, clippy, rustfmt, mold |
| 5 | `ubuntu_dev_n8n` | Ubuntu 24.04 | Node (NVM), n8n |
| 6 | `ubuntu_dev_go` | Ubuntu 24.04 | Go SDK, gopls, delve, air, staticcheck |
| 7 | `ubuntu_dev_devops` | Ubuntu 24.04 | kubectl, helm, terraform, ansible, awscli, gcloud, az, k9s, kustomize, kind |
| 8 | `ubuntu_dev_dotnet` | Ubuntu 24.04 | .NET SDK 8 LTS, PowerShell, Azure CLI |
| 9 | `ubuntu_dev_writing` | Ubuntu 24.04 | LaTeX (FR/EN), Pandoc (+ Eisvogel), Marp, Vale |
| 10 | `ubuntu_dev_data` | Ubuntu 24.04 | uv, DuckDB, JupyterLab, pandas, polars, pgcli/mycli/litecli/harlequin |
| 11 | `ubuntu_dev_php` | Ubuntu 24.04 | PHP 8, Composer, Symfony CLI, Laravel, xdebug, Node (NVM) |
| 12 | `ubuntu_dev_java` | Ubuntu 24.04 | SDKMAN!, Temurin JDK 21/17 LTS, Maven, Gradle, Spring Boot CLI |
| 13 | `ubuntu_dev_video` | Ubuntu 24.04 | ffmpeg, yt-dlp, mkvtoolnix, HandBrakeCLI, mediainfo, whisper.cpp |
| 14 | `ubuntu_dev_security_audit` | Ubuntu 24.04 | Trivy, Syft, Grype, Semgrep, Cosign, Gitleaks, TruffleHog, Checkov |
| 15 | `ubuntu_dev_flutter` | Ubuntu 24.04 | Flutter SDK (stable), Dart, Linux desktop + Web (Chromium) |

> Tous les environnements incluent les utilitaires : `bat`, `ripgrep`, `fzf`, `jq`, `htop`, `tmux`, `tree`, `gh`, `zsh`
>
> Un environnement avancé `fedora_gaming` (base Fedora) existe mais n'est pas affiché dans le menu — voir la structure du projet.

* * *

## 📦 Pré-requis

- Un système **Linux**
- **Podman** ou **Docker** installé et configuré
- **Distrobox** installé
- Connexion Internet
- Espace disque suffisant (plusieurs Go selon l'environnement)

* * *

## ⚙️ Utilisation

### Installation

```bash
git clone https://github.com/benjsant/distroscripts.git
cd distroscripts
./install.sh
```

### Mise à jour des environnements existants

```bash
./update.sh
```

### Désinstallation

```bash
./uninstall.sh
```

### Accéder à un environnement

```bash
distrobox enter ubuntu_dev_python
```

### Corriger la locale (si besoin)

Sur certains hôtes (ex. Nobara), `/etc/locale.conf` contient une forme non
canonique comme `fr_FR.utf8` au lieu de `fr_FR.UTF-8`, ce qui casse
l'initialisation des boxes Ubuntu (`Installing basic packages... Error`).
Les `install.sh` détectent ce cas et proposent le fix automatiquement, mais
les scripts restent disponibles à la main :

```bash
./fix_locale.sh            # diagnostic + propose le fix (backup automatique)
./fix_locale.sh --apply    # applique directement
./revert_locale.sh         # restaure un backup (interactif)
./revert_locale.sh --latest
```

* * *

## 📂 Structure du projet

```
.
├── install.sh            # Menu principal d'installation (14 environnements)
├── update.sh             # Mise à jour des environnements
├── uninstall.sh          # Suppression des environnements
├── fix_locale.sh         # Corrige /etc/locale.conf en forme canonique (.UTF-8)
├── revert_locale.sh      # Restaure un backup de /etc/locale.conf
├── lib/
│   ├── common.sh         # Fonctions partagées (hôte, SELinux, cgroups, GPU, locale, logging)
│   ├── shell_setup.sh    # Helpers communs aux post_install (PATH, prompt, zsh)
│   └── versions.sh       # Versions centralisées (images, NVM, Python, Go…)
├── ubuntu_dev_hugo/      # Chaque environnement contient :
│   ├── install.sh        #   - install.sh       (création de la box)
│   ├── post_install.sh   #   - post_install.sh  (configuration dans la box)
│   └── packages.txt      #   - packages.txt     (paquets apt)
├── ubuntu_dev_python/
├── ubuntu_dev_ia/
├── ubuntu_dev_rust/
├── ubuntu_dev_n8n/
├── ubuntu_dev_go/
├── ubuntu_dev_devops/
├── ubuntu_dev_dotnet/
├── ubuntu_dev_writing/
├── ubuntu_dev_data/
├── ubuntu_dev_php/
├── ubuntu_dev_java/
├── ubuntu_dev_video/
├── ubuntu_dev_security_audit/
├── ubuntu_dev_flutter/
└── fedora_gaming/        # Environnement avancé (non affiché dans le menu)
    ├── install.sh
    ├── setup_repos.sh
    ├── config_amd.sh
    ├── install_packages.sh
    └── packages.txt
```

* * *

## ⚠️ Limitations par environnement

### **Générales**

- **Linux uniquement** : Distrobox ne fonctionne pas nativement sur Windows/macOS
- **Performances** : Dépendent du matériel hôte (CPU, RAM, GPU)
- **Ressources** : Certaines Distrobox peuvent nécessiter plusieurs Go d'espace disque

* * *

### **ubuntu_dev_ia**

- **Accélération GPU** : CUDA (NVIDIA) ou ROCm (AMD) utilisables uniquement si les drivers sont installés sur l'hôte
- **Mode CPU** : En absence de GPU compatible, les traitements IA seront beaucoup plus lents
- **Mémoire** : Les modèles Ollama peuvent consommer plusieurs Go de RAM

* * *

### **ubuntu_dev_hugo**

- **Accès réseau** : Le serveur local Hugo peut être inaccessible si certains ports sont bloqués
- **VPN** : Peut interférer avec le hot reload

* * *

### **ubuntu_dev_python**

- **Temps d'installation** : pyenv compile Python depuis les sources → long sur machines modestes
- **uv** : Complément de pyenv — `uv venv` pour créer un environnement virtuel, `uv pip install` pour installer des paquets

* * *

### **ubuntu_dev_devops / ubuntu_dev_writing**

- **Taille** : ces environnements sont volumineux (DevOps installe 10+ CLI cloud ; Writing installe TeXLive, ~3 Go)
- **DevOps** : `kubectl`/`helm`/`kind` agissent sur des clusters externes — pensez à monter votre `~/.kube/config` si besoin

* * *

### **ubuntu_dev_video**

- **whisper.cpp** : compilé depuis les sources au premier post-install (peut prendre plusieurs minutes), modèle `base` téléchargé (~150 Mo)
- **Transcription** : utilisez la fonction `transcribe <fichier>` fournie

* * *

### **ubuntu_dev_java**

- **SDKMAN!** : gère plusieurs JDK — `sdk list java` pour les versions disponibles, `sdk install java X.Y.Z-tem` pour ajouter un Temurin

* * *

### **ubuntu_dev_flutter**

- **Cibles installées** : Linux desktop + Web (Chromium). Android **n'est pas installé par défaut** — l'émulateur Android nécessite KVM et `adb` veut accéder à l'USB, ce qui complique l'exposition depuis l'hôte.
- **Ajouter Android plus tard** : installer `commandline-tools` officiel + `sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"` + `flutter config --android-sdk ~/Android/Sdk`
- **Premier lancement** : `flutter precache` télécharge le Dart SDK interne et les outils Linux/Web (~1 Go, fait en post-install)

* * *

## 💡 Conseils d'utilisation

- Authentifiez-vous à GitHub dès l'entrée dans l'environnement : `gh auth login`
- Utilisez `uv venv` + `uv pip install` plutôt que `pip` classique (10-100x plus rapide)
- Nettoyez les images inutilisées avec `podman image prune` ou `docker image prune`
- Les logs d'installation sont dans `~/distrobox/<nom>_install.log` en cas de problème
- VS Code est lancé avec `--no-sandbox` (alias automatique) pour fonctionner dans Distrobox

* * *
