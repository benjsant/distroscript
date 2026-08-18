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
| 1 | `ubuntu_dev_python` | Ubuntu 24.04 | pyenv, uv, Node (NVM), VS Code, gh — profil `data` optionnel |
| 2 | `ubuntu_dev_ia` | Ubuntu 24.04 | Ollama, pyenv, uv, PyTorch — GPU NVIDIA/ROCm/CPU |
| 3 | `ubuntu_dev_rust` | Ubuntu 24.04 | rustup, cargo, clippy, rustfmt, mold |
| 4 | `ubuntu_dev_go` | Ubuntu 24.04 | Go SDK, gopls, delve, air, staticcheck |
| 5 | `ubuntu_dev_java` | Ubuntu 24.04 | SDKMAN!, Temurin JDK 21/17 LTS, Maven, Gradle, Spring Boot CLI |
| 6 | `ubuntu_dev_php` | Ubuntu 24.04 | PHP 8, Composer, Symfony CLI, Laravel, xdebug, Node (NVM) |
| 7 | `ubuntu_dev_dotnet` | Ubuntu 24.04 | .NET SDK 8 LTS, PowerShell, Azure CLI |
| 8 | `ubuntu_dev_devops` | Ubuntu 24.04 | kubectl, helm, terraform, ansible, awscli, gcloud, az, k9s, kustomize, kind |
| 9 | `ubuntu_dev_writing` | Ubuntu 24.04 | LaTeX (FR/EN), Pandoc (+ Eisvogel), Marp, Vale |
| 10 | `ubuntu_dev_security_audit` | Ubuntu 24.04 | Trivy, Syft, Grype, Semgrep, Cosign, Gitleaks, TruffleHog, Checkov |
| 11 | `fedora_gaming` | Fedora 44 | Steam, Lutris, Heroic, Wine, umu, Proton, MangoHud, gamescope, émulateurs |
| 12 | `arch_gaming` | steambox (Arch) | Idem, sur l'image gaming maintenue par Universal Blue |

> Les environnements de développement incluent les utilitaires : `bat`, `ripgrep`, `fzf`, `jq`, `htop`, `tmux`, `tree`, `gh`, `zsh`

### Profils

Un environnement peut proposer des **profils** : des variantes qui ajoutent des
paquets et des outils par-dessus l'installation de base. Le menu de `install.sh`
les détecte automatiquement (un profil = un fichier `packages.<profil>.txt`), et
ils sont aussi accessibles en direct :

```bash
./ubuntu_dev_python/install.sh --profile data
```

| Environnement | Profil | Ajoute |
| --- | --- | --- |
| `ubuntu_dev_python` | `data` | DuckDB, JupyterLab, pandas, polars, pyarrow, scikit-learn, pgcli/mycli/litecli/harlequin, venv `~/data_env` (alias `data-env`) |

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
├── install.sh            # Menu principal d'installation (auto-découverte des envs)
├── update.sh             # Mise à jour des environnements
├── uninstall.sh          # Suppression des environnements
├── status.sh             # État des environnements + résumé de l'hôte
├── fix_locale.sh         # Corrige /etc/locale.conf en forme canonique (.UTF-8)
├── revert_locale.sh      # Restaure un backup de /etc/locale.conf
├── lib/
│   ├── common.sh         # Fonctions partagées (hôte, SELinux, cgroups, GPU, locale, logging)
│   ├── shell_setup.sh    # Helpers communs aux post_install (PATH, prompt, zsh)
│   └── versions.sh       # Versions centralisées (images, NVM, Python, Go…)
├── ubuntu_dev_python/    # Chaque environnement contient :
│   ├── install.sh        #   - install.sh          (création de la box)
│   ├── post_install.sh   #   - post_install.sh     (configuration dans la box)
│   ├── packages.txt      #   - packages.txt        (paquets apt)
│   └── packages.data.txt #   - packages.<p>.txt    (paquets d'un profil, optionnel)
├── ubuntu_dev_ia/
├── ubuntu_dev_rust/
├── ubuntu_dev_go/
├── ubuntu_dev_java/
├── ubuntu_dev_php/
├── ubuntu_dev_dotnet/
├── ubuntu_dev_devops/
├── ubuntu_dev_writing/
├── ubuntu_dev_security_audit/
├── fedora_gaming/        # Environnement de jeu (base Fedora)
│   ├── install.sh
│   ├── post_install.sh
│   └── packages.txt
├── arch_gaming/          # Environnement de jeu (base steambox / Arch)
└── assemble/             # Pilote distrobox-assemble (voir assemble/README.md)
    └── generate.sh
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

### **ubuntu_dev_python**

- **Temps d'installation** : pyenv compile Python depuis les sources → long sur machines modestes
- **uv** : Complément de pyenv — `uv venv` pour créer un environnement virtuel, `uv pip install` pour installer des paquets
- **Profil `data`** : ajoute ~1 Go (JupyterLab + stack scientifique dans `~/data_env`). Le venv est séparé du Python global de pyenv : activez-le avec `data-env` avant de lancer `jupyter lab`.

* * *

### **ubuntu_dev_devops / ubuntu_dev_writing**

- **Taille** : ces environnements sont volumineux (DevOps installe 10+ CLI cloud ; Writing installe TeXLive, ~3 Go)
- **DevOps** : `kubectl`/`helm`/`kind` agissent sur des clusters externes — pensez à monter votre `~/.kube/config` si besoin

* * *

### **ubuntu_dev_java**

- **SDKMAN!** : gère plusieurs JDK — `sdk list java` pour les versions disponibles, `sdk install java X.Y.Z-tem` pour ajouter un Temurin

* * *

### **ubuntu_dev_security_audit**

- **API GitHub** : plusieurs outils (Cosign, Gitleaks) résolvent leur dernière version via `api.github.com`, limitée à 60 requêtes/h sans authentification. Exportez `GITHUB_TOKEN` si vous relancez le post-install plusieurs fois.

* * *

### **fedora_gaming**

L'objectif : **tout le nécessaire pour jouer tient dans la box**, l'hôte reste
propre. Aucun paquet Wine, Steam ou mesa n'est installé sur le système hôte —
sur une nouvelle machine, un seul script rétablit l'environnement complet.

```bash
./fedora_gaming/install.sh                        # jeux dans ~/Games
./fedora_gaming/install.sh --games-dir /mnt/ssd/jeux
```

- **Ce qui est portable** : le conteneur est jetable, l'état ne l'est pas. Les
  configs vivent dans `~/distrobox/fedora_gaming`, les jeux et les préfixes Wine
  dans `$GAMES_DIR` (monté depuis l'hôte, donc il survit à une recréation de la
  box). **Migrer = copier ces deux dossiers et relancer le script.**
- **Préfixes Wine** : `WINEPREFIX` pointe dans `$GAMES_DIR/prefixes` et non dans
  `~/.wine`. Changer de préfixe : `wineprefix <nom>`.
- **Lanceurs** : Steam, Lutris, Heroic et les émulateurs sont exportés vers le
  menu d'applications de l'hôte via `distrobox-export` — pas besoin de passer par
  `distrobox enter` pour jouer.
- **Aucun pré-requis bloquant** : si le bus D-Bus ou la délégation cgroups v2
  manquent, le script prévient et continue en mode dégradé. Seul `gamemode` exige
  systemd dans la box (donc la délégation cgroups) ; tout le reste fonctionne sans.
- **GPU AMD / Intel** : le rendu passe par le mesa de la box, aucune contrainte de
  version avec l'hôte.
- **GPU NVIDIA** : nécessite `nvidia-container-toolkit` sur l'hôte, et les
  versions du driver hôte et des libs injectées doivent correspondre. Le script
  détecte le cas et demande confirmation avant de continuer sans.
- **Bibliothèque Steam existante** : ne la copiez pas, montez-la —
  `--games-dir /chemin/vers/le/disque`.
- **Flatpak** : volontairement absent de la box — flatpak dans un conteneur ne
  fonctionne pas.
- **Paquets vérifiés** : la disponibilité de chaque entrée de `packages.txt` a
  été contrôlée dans une `fedora-toolbox:44` réelle avec RPM Fusion et Terra.
  N'ajoutez pas de paquet sans le vérifier — les noms diffèrent entre Fedora,
  Nobara et Arch (`heroic-games-launcher` sur Fedora contre
  `heroic-games-launcher-bin` sur l'AUR, par exemple).
- **Dépôt Terra** : fournit `umu-launcher`, `heroic-games-launcher` et
  `protonplus`. Préféré aux COPR gaming répandus (`gloriouseggroll/nobara-*`),
  qui sont des overlays de distro complets déconseillés hors Nobara.
  Terra est maintenu par Fyra Labs (l'équipe d'Ultramarine Linux) et est le
  dépôt tiers qu'utilise Nobara. Il reste un dépôt tiers : la box le restreint
  donc par `includepkgs` à ces trois paquets, si bien qu'il ne peut masquer
  aucun paquet Fedora ou RPM Fusion. Sa clé est importée explicitement et
  `repo_gpgcheck=1` vérifie aussi la signature des métadonnées.
- **wine-staging** : Fedora ne fournit que wine stable. Pour staging, ajoutez le
  [dépôt WineHQ](https://gitlab.winehq.org/wine/wine/-/wikis/Download) — ou
  utilisez `arch_gaming`, où staging est dans les dépôts officiels.

* * *

### **arch_gaming**

Même objectif que `fedora_gaming`, autre pari : au lieu de construire la box
paquet par paquet, on part de **`ghcr.io/ublue-os/steambox`**, l'image OCI
gaming maintenue par [Universal Blue](https://github.com/ublue-os/toolboxes)
(successeur de `bazzite-arch`, archivé en mars 2026).

```bash
./arch_gaming/install.sh
./arch_gaming/install.sh --games-dir /mnt/ssd/jeux
```

- **Ce que l'image apporte déjà** : Steam, Lutris, Wine, MangoHud, vkBasalt
  (tous en 64 **et** 32 bits), protontricks, steamcmd, la pile audio PipeWire
  complète en 32 bits, les couches Vulkan mesa 32 bits, le runtime ROCm,
  LatencyFleX et obs-vkcapture. C'est la partie la plus pénible à assembler
  soi-même, et elle est déléguée à des mainteneurs dont c'est le métier.
- **Ce que le post-install ajoute** : `umu-launcher`, `wine-staging`,
  `gamescope`, `gamemode` (+ lib32), `goverlay`, `antimicrox`, les émulateurs —
  tous présents dans les dépôts Arch officiels. Heroic et ProtonPlus viennent
  de l'AUR via `paru`, et leur échec n'est pas bloquant.
- **Taille** : l'image pèse **~11 Go**. C'est le prix à payer, en échange d'une
  box prête sans compilation ni résolution de dépendances.
- **`--unshare-netns`** : recommandé en amont, et indispensable si Steam tourne
  aussi sur l'hôte — deux Steam dans le même namespace réseau se disputent les
  mêmes ports.
- **Arch et la stabilité** : le conteneur est jetable et l'image est construite
  et testée en amont ; une régression Arch ne touche pas l'hôte, et l'image peut
  être épinglée par digest ou rollbackée.

* * *

## 💡 Conseils d'utilisation

- Authentifiez-vous à GitHub dès l'entrée dans l'environnement : `gh auth login`
- Utilisez `uv venv` + `uv pip install` plutôt que `pip` classique (10-100x plus rapide)
- Nettoyez les images inutilisées avec `podman image prune` ou `docker image prune`
- Les logs d'installation sont dans `~/distrobox/<nom>_install.log` en cas de problème
- VS Code est lancé avec `--no-sandbox` (alias automatique) pour fonctionner dans Distrobox

* * *
