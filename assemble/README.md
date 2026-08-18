# Pilote `distrobox assemble`

Évaluation de `distrobox assemble` comme remplaçant de la partie déclarative
des `install.sh`. **Rien n'est migré** : le flux normal (`./install.sh`) est
inchangé, ce dossier est un bac à sable pour décider.

Testé avec distrobox **1.8.2.5**.

## Essayer

```bash
./assemble/generate.sh ubuntu_dev_go              # manifeste sur stdout
./assemble/generate.sh ubuntu_dev_go -o box.ini
./assemble/generate.sh fedora_gaming --games-dir /Data/Jeux
./assemble/generate.sh --all -o distrobox.ini     # les 12 environnements

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

## Couverture

Les trois bases sont prises en charge :

| Base | Forme d'entrée | Particularités |
| --- | --- | --- |
| `ubuntu_*` | `manifest_entry_ubuntu` | hérite de `[base_ubuntu]`, paquets via `additional_packages` |
| `fedora_gaming` | `manifest_entry_gaming` | périphériques, GID de groupes, socket audio, D-Bus, `init` conditionnel |
| `arch_gaming` | `manifest_entry_gaming` | idem + `unshare_netns=true` |

Les box gaming sont celles qui gagnent le plus à être générées : ce sont elles
qui ont le plus de flags dépendants de l'hôte, donc celles qu'il serait le plus
faux d'écrire à la main. Exemple réel sur la machine de référence :

```ini
[fedora_gaming]
image=quay.io/fedora/fedora-toolbox:44
volume=/Data/Jeux:/Data/Jeux
volume=/run/user/1000:/run/user/1000
# init=true omis : délégation cgroups v2 absente (gamemode indisponible)
additional_flags=--device=/dev/dri --device=/dev/snd --device=/dev/input \
  --device=/dev/uinput --group-add=105 --group-add=104 --group-add=63 \
  --group-add=39 --env=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
```

Les quatre `--group-add`, la présence de `/dev/uinput`, celle du bus D-Bus et
l'absence de `init=true` sont toutes des constatations faites sur CETTE machine.
Sur une autre, les quatre GID diffèrent et `init=true` peut réapparaître.

Pour les box gaming, les paquets restent installés par le `post_install.sh` et
non par `additional_packages` : voir la réserve plus haut sur
`--skip-unavailable`.

**Limite connue** : `distrobox assemble` joint `additional_flags` par des
espaces et enveloppe `init_hooks` dans des simples quotes, sans échappement. Un
`--games-dir` contenant un espace ou une apostrophe produirait un manifeste
cassé en silence — `generate.sh` refuse donc explicitement ces chemins.

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
