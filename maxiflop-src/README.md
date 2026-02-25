# MAXIFLOP — Jeu de Rythme (Solo)
*Inspiré de Osu! Taiko*

## Structure du projet

```
maxiflop/
├── project.godot          ← Ouvrir avec Godot 4.4
├── scenes/
│   ├── MainMenu.tscn      ← Écran d'accueil
│   ├── GameScreen.tscn    ← Scène de jeu principale
│   └── Note.tscn          ← Scène d'une note (préfab)
├── scripts/
│   ├── GameManager.gd     ← Singleton (Autoload)
│   ├── GameScreen.gd      ← Contrôleur principal
│   ├── NoteSpawner.gd     ← Spawn + beatmap
│   ├── HitZone.gd         ← Détection d'input/hit
│   ├── Note.gd            ← Comportement d'une note
│   └── MainMenu.gd        ← Menu principal
└── assets/                ← Musiques, fonts, sprites...
```

## Installation

1. Ouvrir **Godot 4.4**
2. Importer le dossier `maxiflop/`
3. Dans **Projet → Paramètres du projet → Autoload**, ajouter :
   - Script : `res://scripts/GameManager.gd`
   - Nom : `GameManager`
4. Lancer le projet (`F5`)

## Contrôles

| Touche | Action |
|--------|--------|
| `A` | Frapper note **Bleue** |
| `S` | Frapper note **Jaune** |
| `D` | Frapper note **Rouge** |
| `Échap` | Retour au menu |

## Système de score

| Précision | Points |
|-----------|--------|
| **PERFECT** (< 80ms) | 300 pts |
| **GOOD** (< 150ms) | 100 pts |
| **BAD** (< 250ms) | 50 pts |
| **MISS** | 0 pts |

### Multiplicateurs de combo
- Combo ≥ 5 → **×2**
- Combo ≥ 10 → **×3**
- Combo ≥ 20 → **×4**

## Ajouter de la musique

1. Importer un fichier `.ogg` ou `.wav` dans `assets/`
2. Dans la scène `GameScreen.tscn`, sélectionner le nœud `MusicPlayer`
3. Assigner le stream audio
4. Adapter `song_duration` dans le script `GameScreen.gd`




## Prochaines étapes (multijoueur)

- Manette HTML/CSS pour mobile (Gwen)
- Équipes et leaderboard global
- Beatmaps depuis fichiers JSON

# Back-end - Florence

## Terminé
- Initialisation Serveur : Serveur Node.js (configuré et init)
- Communication : Socket.io (installé)
- Sécurité : .gitignore mis à jour

## En cours et à faire

### Manette / Gestion Joueurs
- Récupération du pseudo : Ecouter l'évènement émis par le client, stocker les pseudos coté serveur
- Suivi des connexions
- Recevoir et valider les signaux envoyés par les téléphones

### API
- API manette (en cours)
- API Leaderboard : Route GET pour renvoyer le top 5
- API musique

### Synchro
- Transmettre les inputs reçus à Godot
- envoi d'un signal au serveur quand un utilisateur clique sur un bouton

