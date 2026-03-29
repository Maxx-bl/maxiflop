# 🚀 Guide de démarrage - Maxiflop

## En mode Éditeur Godot
1. Ouvre le projet dans Godot.
2. Appuie sur **F5** (ou le bouton ▶️).
3. C'est tout ! Le serveur Node.js et le tunnel public démarrent automatiquement en arrière-plan.

## En mode Exécutable (.x86_64 / .exe)
> ⚠️ Le dossier `maxiflop-server/` **doit être dans le même répertoire** que l'exécutable compilé.

Structure attendue :
```
maxiflop/
├── maxiflop.x86_64     ← ton exécutable Godot
└── maxiflop-server/    ← le serveur Node.js (avec node_modules/)
    └── server.js
```

1. Assure-toi que `node` est installé sur la machine (`node --version`).
2. Lance l'exécutable. Le serveur Node.js démarre seul.

---

## Connexion des joueurs
- Après ~5 secondes, le **QR Code** sur l'écran de jeu se met à jour avec l'URL publique.
- Les joueurs **scannent le QR Code**, saisissent leur pseudo et choisissent une équipe.
- Le bouton **"Lancer la partie"** se débloque quand les équipes sont équilibrées (≥2 équipes, écart ≤3).

## En cas de problème de réseau (QR Code mort)
Lance dans un terminal :
```bash
ssh -o StrictHostKeyChecking=no -R 80:localhost:3000 nokey@localhost.run
```
Copie le lien `.lhr.life` généré → colle-le dans la case **`Join Url Override`** de la scène `GameScreen` dans l'Inspecteur Godot.
