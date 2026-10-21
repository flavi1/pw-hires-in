# rock-n-roll-pw-in

Réception, sur la Raspberry Pi, du son d'un PC par le réseau local, **sans perte et
sans compression** : RTP, 192 kHz / 24 bits, tampon de 10 ms en Ethernet.

Module de la famille [pi-server](https://github.com/flavi1/pi-server), à installer
**après [pi-sound-server](https://github.com/flavi1/pi-sound-server)** : le son reçu
entre dans `MASTER` comme n'importe quelle autre source (volume du knob, toutes les
sorties). Côté PC : [rock-n-roll-pw-out](https://github.com/flavi1/rock-n-roll-pw-out).

```
PC (PipeWire)                         Raspberry Pi
 appli → « Hifi — Ethernet » ─RTP 192 kHz/24 bits─▶ rock-n-roll.rtp ─▶ MASTER ─▶ DAC / ampli
                         UDP 46000, réseau local
```

## Installation

Avec pi-server :

```
sudo pi-server add net
```

Ou à la main :

```
git clone https://github.com/flavi1/rock-n-roll-pw-in.git
sudo bash rock-n-roll-pw-in/install.sh
```

Puis, sur le PC, voir [rock-n-roll-pw-out](https://github.com/flavi1/rock-n-roll-pw-out).

## Fonctionnement

- **Un seul émetteur à la fois**, **réseau local uniquement**, sans mot de passe :
  c'est le pare-feu de pi-server qui l'assure (ensemble nftables à une seule place).
  Le premier PC qui envoie garde la place **tant qu'il envoie, même du silence** ;
  elle se libère `release-seconds` (5 s) après son dernier paquet. Les paquets d'un
  second PC sont rejetés par le noyau en attendant : jamais de mélange de deux flux.
- **Format fixe** : 192 kHz, 24 bits, stéréo, identique des deux côtés. Le PC
  convertit ce qu'il joue vers 192 kHz (qualité PipeWire) ; la Pi n'a rien à
  renégocier.
- Le récepteur tourne dans **son propre processus PipeWire** (service utilisateur
  `rock-n-roll-rtp` de l'utilisateur `hifi`) : il peut être relancé sans toucher au
  reste (Mopidy, radios, Bluetooth continuent).
- Les radios et la musique de Mopidy, le Bluetooth, la platine… restent utilisables en
  parallèle : tout se mélange dans `MASTER`.
- Sans pare-feu pi-server, le port n'est pas filtré et rien n'empêche deux émetteurs
  de se mélanger (avertissement à l'installation).

## Configuration

`/etc/rock-n-roll-pw-in/pw-in.conf` est **déployé depuis le dépôt** (l'ancien est gardé :
`pw-in.conf.avant-maj`). Réglages propres à votre Pi : `/etc/rock-n-roll-pw-in/local.conf`
(mêmes sections, lu après, jamais écrasé). Après modification :

```
sudo rock-n-roll-pw-in apply
```

| Section | Clé | Défaut | Rôle |
|---|---|---|---|
| `[global]` | `user` | `auto` | utilisateur PipeWire (celui de pi-sound-server, sinon `hifi`) |
| | `target` | `auto` | sortie visée (`MASTER` de pi-sound-server) |
| | `resample.quality` | `auto` | qualité de l'ajustement d'horloge (celle de pi-sound-server : 10) |
| `[rtp]` | `enabled` | `yes` | récepteur actif |
| | `port` | `46000` | port UDP |
| | `latency-ms` | `10` | tampon : Ethernet 5 à 10, Wi-Fi 50 à 200 |
| | `rate`, `format`, `channels` | `192000`, `S24BE`, `2` | **doivent être identiques côté PC** |
| | `release-seconds` | `5` | silence réseau avant qu'un autre PC puisse prendre la place |
| | `description` | `Réseau (RTP)` | nom affiché |

## État

```
sudo rock-n-roll-pw-in status
```

```
  RTP         : port UDP 46000, 192000 Hz S24BE 2 canaux, tampon 10 ms, place libérée après 5 s
  service     : active
  flux        : en réception
  émetteur    : 192.168.1.20
```

## Dépannage

| Symptôme | Piste |
|---|---|
| Pas de son, `flux : en attente d'un émetteur` | côté PC, la sortie « Hifi — Ethernet » est-elle choisie ? Même port ? `sudo nft list set inet filter rnr_rtp_sender` : un autre PC tient la place ? |
| `émetteur : 192.168.1.x` qui n'est pas le bon PC | l'autre PC envoie encore (même du silence) : arrêtez-le ou changez sa sortie ; la place se libère 5 s après |
| PC sur un autre sous-réseau | `LAN4` de pi-server (`/etc/pi-server/pi-server.conf`) |
| Son haché | réseau chargé ou Wi-Fi : `latency-ms = 30` (ou plus) dans `local.conf`, puis `apply` |
| Son trop aigu / grave, craquements réguliers | format différent des deux côtés : `rate` / `format` |
| Journal | `sudo journalctl _UID=$(id -u hifi) --user-unit=rock-n-roll-rtp -f` |

## Tests

```
bash tests/test-config.sh          # configuration et fichiers générés
sudo python3 tests/test-firewall.py   # pare-feu réel dans un espace réseau isolé
```

## Licence

GPL-3.0-or-later
