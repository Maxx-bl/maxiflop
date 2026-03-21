# 🎵 Maxiflop

Jeu de rythme multijoueur en équipe inspiré de **Osu! Taiko**. Un écran principal orchestre la partie pendant que les joueurs utilisent leurs téléphones comme manettes via un navigateur web.

## Équipe

Florence **Regnier-Beck** · Maxandre **Berson-Lefuel** · Pompaline **Wan**

---

## Concept

Des notes colorées (bleu, jaune, rouge) tombent sur l'écran principal. Les joueurs doivent appuyer sur le bouton correspondant au bon moment depuis leur téléphone. Plus le timing est précis, plus les points sont élevés. Les joueurs sont répartis aléatoirement en deux équipes — l'équipe avec le score cumulé le plus élevé remporte la partie.

---

## Fonctionnalités

- **Multijoueur local** : rejoindre via QR code ou URL Wi-Fi, sans installation
- **Manette web** : interface navigateur responsive, format paysage en jeu
- **Équipes aléatoires** : répartition automatique en équipe bleue ou rouge
- **Scoring** : PERFECT / GOOD / BAD avec multiplicateur de combo (x2 à x4)
- **Pénalité** : −400 pts pour tout clic dans le vide
- **Retour haptique** : vibration + flash de couleur à chaque note sur mobile
- **Classement live** : Top 5 joueurs et progression des équipes en temps réel
- **Génération aléatoire** : beatmap différente à chaque partie (notes simples, doubles simultanées, demi-beats)
- **Durée fixe** : 30 secondes par partie

---

## Stack technique

| Composant     | Technologie                        |
| ------------- | ---------------------------------- |
| Jeu (host)    | Godot 4.4 · GDScript               |
| Serveur       | Node.js · Express · WebSocket (ws) |
| Manette       | HTML / CSS / JavaScript            |
| Communication | WebSocket (ws://)                  |

---

## Structure du projet

```
maxiflop-src/          → Projet Godot (scènes, scripts)
  scenes/
    MainMenu.tscn
    GameScreen.tscn
    Note.tscn
  scripts/
    GameManager.gd     → Autoload : score, combo, événements
    MultiplayerBridge.gd → Autoload : communication WebSocket host
    ServerManager.gd   → Autoload : lance/arrête le serveur Node.js
    GameScreen.gd      → Logique principale de la partie
    NoteSpawner.gd     → Génération aléatoire de la beatmap
    HitZone.gd         → Détection des hits et pénalités
    Note.gd            → Comportement et animation des notes

maxiflop-server/       → Serveur Node.js
  server.js            → Lobby, WebSocket, gestion des joueurs

maxiflop-smartphone/   → Interface manette
  index.html
  style.css
  script.js
```

---

## Lancement

### Prérequis

- [Godot 4.4](https://godotengine.org/)
- [Node.js](https://nodejs.org/) (≥ 18)

### En développement

```bash
# Lancer le serveur manuellement (si ServerManager désactivé)
cd maxiflop-server
npm install
npm start
```

Puis lancer la scène `MainMenu.tscn` dans l'éditeur Godot.

### En production (exécutable exporté)

Le serveur Node.js est lancé automatiquement par `ServerManager.gd` au démarrage du jeu. Placer `maxiflop-server/` et `maxiflop-smartphone/` dans le même dossier que l'exécutable.

```
Maxiflop.exe
maxiflop-server/
  server.js
  node_modules/
maxiflop-smartphone/
  index.html
  style.css
  script.js
```

---

## Rejoindre une partie

1. Lancer le jeu sur l'écran principal (host)
2. Scanner le **QR code** affiché en salle d'attente, ou ouvrir l'URL indiquée (`http://192.168.x.x:8080`) sur son téléphone
3. Choisir un pseudo et rejoindre
4. Le host clique sur **Lancer la partie** → décompte de 5 secondes → GO !

---

## Règles de scoring

| Résultat  | Points | Condition               |
| --------- | ------ | ----------------------- |
| PERFECT   | 300    | Timing < 50 ms          |
| GOOD      | 100    | Timing < 150 ms         |
| BAD       | 50     | Timing < 250 ms         |
| MISS      | 0      | Note ratée              |
| Clic vide | −400   | Aucune note à proximité |

Le score d'équipe est la somme des scores individuels. Le combo x2 se déclenche à partir de 5 notes consécutives (x3 à 10, x4 à 20).
