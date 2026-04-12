# 🚀 Maxiflop

Jeu de rythme multijoueur en équipe inspiré de **Osu! Taiko**. Un écran principal orchestre la partie pendant que les joueurs utilisent leurs téléphones comme manettes via un navigateur web. Le jeu intègre un système de vote, des équipes, et une jouabilité accessible en ligne via un tunnel.

## Équipe
Florence **Regnier-Beck** · Maxandre **Berson-Lefuel** · Pompaline **Wan**

---

## Concept
Des notes colorées tombent sur l'écran principal. Les joueurs doivent appuyer sur le bouton correspondant au bon moment depuis leur téléphone. Plus le timing est précis, plus les points sont élevés. Les joueurs choisissent entre plusieurs équipes, et doivent s'équilibrer pour que la partie se lance. L'équipe avec le score cumulé le plus élevé remporte la partie !

---

## Fonctionnalités
- **Multijoueur Facilité** : Le jeu déploie automatiquement un tunnel (Cloudflare) permettant aux joueurs de rejoindre via Internet en scannant simplement un QR Code.
- **Manette Web** : Interface sur navigateur responsive (pas d'application à installer).
- **Choix d'Équipe et Équilibrage** : Les joueurs choisissent parmi trois équipes (Equipe 1, 2 ou 3). Le jeu empêche le lancement si les équipes sont trop déséquilibrées (écart > 2).
- **Vote de Musique** : Les joueurs peuvent voter pour leur musique préférée dans le lobby avant de jouer.
- **Scoring & Feedback** : Système de score (PERFECT, GOOD, BAD, MISS, Pénalité de clic dans le vide) avec combo de groupe et retour en temps réel sur l'écran du joueur.
- **Classement Live** : Mise à jour en temps réel des statistiques entre le serveur, l'écran hôte (Godot) et les smartphones.

---

## Stack technique

| Composant     | Technologie                                  |
| ------------- | -------------------------------------------- |
| Jeu (host)    | Godot 4.4 · GDScript                         |
| Serveur       | Node.js · Express · Socket.io · Child Process|
| Tunnel        | Cloudflared (npx) / localhost.run            |
| Manette       | HTML / CSS / JavaScript (Vanilla)            |
| Communication | Socket.IO (Bidirectionnel Temps Réel)        |

---

## Structure du projet

```
maxiflop-src/          → Projet Godot (scènes, scripts, beatmaps, logique client host)
maxiflop-server/       → Serveur backend Node.js (serveur de jeu / bridge)
maxiflop-smartphone/   → Interface web de la manette (servie par Express)
```

---

## Lancement

### En mode Éditeur Godot
1. Ouvre le projet dans Godot.
2. Appuie sur **F5** (ou le bouton ▶️).
3. Le serveur Node.js et le tunnel public Cloudflare démarrent automatiquement en arrière-plan via un script Godot !

### En mode Exécutable (.x86_64 / .exe)
> ⚠️ Le dossier `maxiflop-server/` **doit être dans le même répertoire** que l'exécutable compilé.

Structure attendue :
```
maxiflop/
├── maxiflop.x86_64     ← Exécutable Godot
├── maxiflop-server/    ← Serveur Node.js (doit contenir le sous-dossier node_modules/)
└── maxiflop-smartphone/← Fichiers de la manette (index.html, css, js)
```

1. Assure-toi que `node` est installé sur la machine (`node --version`).
2. Lance l'exécutable. Le serveur Node.js démarre tout seul.

---

## Connexion des joueurs

1. **Host** : Lancer le jeu principal.
2. **Tunnel** : Après environ 5 secondes, le tunnel Cloudflare s'ouvre, le **QR Code** sur l'écran se met à jour avec l'URL publique générée.
3. **Clients (Smartphones)** : Les joueurs scannent le QR Code, saisissent leur pseudo, choisissent une équipe, et votent pour la musique.
4. **Lancement** : Le bouton **"Lancer la partie"** se débloque quand les équipes sont équilibrées. Le compte à rebours démarre !

> **En cas de problème réseaux (QR Code mort / Cloudflare HS) :**
> Lancer dans un terminal : `ssh -o StrictHostKeyChecking=no -R 80:localhost:3000 nokey@localhost.run` et copier le lien `.lhr.life` dans la case **`Join Url Override`** de l'inspecteur de la scène `GameScreen` dans Godot.

---

## Règles de scoring

| Résultat  | Points | Condition               |
| --------- | ------ | ----------------------- |
| PERFECT   | 300    | Timing très précis      |
| GOOD      | 100    | Timing correct          |
| BAD       | 50     | Timing limite           |
| MISS      | 0      | Note ratée              |
| Clic vide | −400   | Aucune note à proximité |

Le score d'équipe est la somme des scores individuels. Maintenir le combo débloque des multiplicateurs.
