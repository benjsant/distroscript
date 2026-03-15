# 📦 DistroScript

![image](featured_image.png)

**DistroScript** est un ensemble de scripts Bash permettant de créer et configurer automatiquement des environnements de développement isolés grâce à **Distrobox**.
Chaque environnement est basé sur Ubuntu 24.04 et préinstallé avec les outils nécessaires à un usage ciblé.

* * *

## 🚀 Fonctionnalités

- Création automatisée de **Distrobox** dédiées selon le besoin
- Scripts de **post-installation** pour configurer chaque environnement
- **Détection GPU NVIDIA** automatique — support activé si disponible
- **Logs** d'installation sauvegardés dans `~/distrobox/<nom>_install.log`
- **Vérification post-install** des outils clés
- Script de **mise à jour** des environnements existants
- Script de **désinstallation** propre
- Choix interactif de l'environnement à installer

* * *

## 📋 Environnements disponibles

| Nom | Base | Outils principaux |
| --- | --- | --- |
| `ubuntu_dev_hugo` | Ubuntu 24.04 | Hugo, Homebrew, Node (NVM), VS Code, gh |
| `ubuntu_dev_python` | Ubuntu 24.04 | pyenv, uv, Node (NVM), VS Code, gh |
| `ubuntu_dev_ia` | Ubuntu 24.04 | Ollama, pyenv, uv, VS Code, gh — GPU NVIDIA/ROCm/CPU |

> Tous les environnements incluent : `bat`, `ripgrep`, `fzf`, `jq`, `htop`, `tmux`, `tree`, `gh`

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

* * *

## 📂 Structure du projet

```
.
├── install.sh            # Menu principal d'installation
├── update.sh             # Mise à jour des environnements
├── uninstall.sh          # Suppression des environnements
├── lib/
│   ├── common.sh         # Fonctions partagées (logging, vérifications, GPU)
│   └── versions.sh       # Versions centralisées (images, NVM, Python…)
├── ubuntu_dev_hugo/
│   ├── install.sh
│   ├── post_install.sh
│   └── packages.txt
├── ubuntu_dev_python/
│   ├── install.sh
│   ├── post_install.sh
│   └── packages.txt
├── ubuntu_dev_ia/
│   ├── install.sh
│   ├── post_install.sh
│   └── packages.txt
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

## 💡 Conseils d'utilisation

- Authentifiez-vous à GitHub dès l'entrée dans l'environnement : `gh auth login`
- Utilisez `uv venv` + `uv pip install` plutôt que `pip` classique (10-100x plus rapide)
- Nettoyez les images inutilisées avec `podman image prune` ou `docker image prune`
- Les logs d'installation sont dans `~/distrobox/<nom>_install.log` en cas de problème
- VS Code est lancé avec `--no-sandbox` (alias automatique) pour fonctionner dans Distrobox

* * *
