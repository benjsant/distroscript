# Pilote `distrobox assemble`

Évaluation de `distrobox assemble` comme remplaçant de la partie déclarative
des `install.sh`. **Rien n'est migré** : le flux normal (`./install.sh`) est
inchangé, ce dossier est un bac à sable pour décider.

Testé avec distrobox **1.8.2.5**.

## Essayer

```bash
./assemble/generate.sh ubuntu_dev_go              # manifeste sur stdout
./assemble/generate.sh ubuntu_dev_go -o box.ini

distrobox assemble create --file box.ini --dry-run   # inspecter, ne crée rien
distrobox assemble create --file box.ini
distrobox assemble create --file box.ini --replace   # recréation idempotente
distrobox assemble rm     --file box.ini
```

## Ce que `assemble` sait faire

Vérifié par `--dry-run`, pas supposé :

| Clé INI | Remplace |
| --- | --- |
| `image` | `--image` de `distrobox-create` |
| `additional_packages` | `packages.txt` + le `xargs apt-get install` |
| `additional_flags` | la construction manuelle de `EXTRA_FLAGS` |
| `home` | `--home` |
| `init` | `--init` (produit `--systemd=always`) |
| `nvidia` | le flag `--nvidia` |
| `volume` | les `--volume` manuels, suffixe `:z` compris |
| `init_hooks` | l'appel `distrobox enter … -- bash post_install.sh` |
| `exported_apps` / `exported_bins` | les boucles `distrobox-export` |
| `include` | **la duplication entre `packages.txt`** |

`include` est le gain le plus net. Le bloc « utilitaires dev »
(`bat ripgrep fzf jq htop tree tmux gh rsync zsh`) est aujourd'hui recopié
dans chaque `packages.txt`. Avec une entrée `[base_ubuntu]` héritée, il est
déclaré une fois. Le cumul est confirmé par le dry-run : les
`additional_packages` de l'entrée incluse et de l'entrée incluante
s'additionnent, et `home` surcharge correctement.

## Ce que `assemble` ne sait pas faire

Le manifeste est **statique**, et c'est la limite structurante : il ne peut pas
faire de détection d'hôte, poser une question, ni logguer.

Un `distrobox.ini` écrit à la main et versionné serait **faux dès qu'on change
de machine** — le GID du groupe `render` diffère, SELinux peut être absent
(donc pas de suffixe `:z`), le toolkit NVIDIA peut manquer. Or c'est
exactement ce que `lib/common.sh` sait faire.

D'où l'architecture retenue pour ce pilote — bash *puis* assemble, chacun sur
son terrain :

```
install.sh (bash)          détecte l'hôte, pose les questions, logue
     ↓ génère
distrobox.ini              manifeste calculé pour CETTE machine
     ↓
distrobox assemble create  crée la box
```

Les manifestes générés ne doivent donc **pas être versionnés** (voir
`.gitignore`). C'est le générateur qui l'est.

Restent hors de portée d'`assemble`, et donc à conserver en bash :
`check_locale_for_ubuntu_box`, `enable_logging`, `check_or_recreate_box`, le
choix de profil, et les vérifications post-install.

## Deux réserves avant de migrer les 10 autres

**Gestion d'erreur sur les paquets.** `additional_packages` installe via
`distrobox-init`, sans l'équivalent du `--skip-unavailable` et du rapport de
paquets manquants ajoutés dans `fedora_gaming/post_install.sh`. Pour Fedora et
ses COPR, où un dépôt tiers cassé sur une nouvelle release est un cas réel,
garder l'installation dans le `post_install.sh` reste plus robuste.

**Contexte d'exécution des `init_hooks`.** Non vérifié : sous quel utilisateur
tournent-ils, et `sudo` y est-il utilisable ? À tester avant de migrer un
`post_install.sh` qui en fait usage.

## Observation du pilote

Le dry-run sur `ubuntu_dev_go` montre les paquets communs **en double** —
`[base_ubuntu]` les déclare, et `ubuntu_dev_go/packages.txt` les contient
encore. `apt` s'en accommode, mais c'est le signe de ce que la migration doit
faire : réduire chaque `packages.txt` à son delta.

Pour `ubuntu_dev_go`, il ne resterait que :

```
pkg-config
gcc
libsqlite3-dev
sqlite3
```

soit 4 lignes au lieu de 22.
