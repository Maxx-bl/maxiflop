const express = require('express');
const { createServer } = require('node:http');
const { join } = require('node:path');
const { Server } = require('socket.io');

const app = express();
const server = createServer(app);
const io = new Server(server);
const port = 3000;

const frontend = join(__dirname, '../../maxiflop-smartphone');

//le serveur prend aussi le css et js du front
app.use(express.static(frontend));

//redirection vers le front quand on va sur "/" (express route)"
app.get('/', (req, res) => {
    res.sendFile(join(frontend, 'index.html'));
});

//GameState

const gameState = {
    status: "lobby",
    teams: [
        { name: "Equipe1", players: [] },
        { name: "Equipe2", players: [] },
        { name: "Equipe3", players: [] },
    ],
    players: {}
}

// fonction lancement
function lancerPartie() {
    // 1 joueur mini dans chaque equipes
    const equipesFull = gameState.teams.filter(t => t.players.length > 0);

    // mini 2 equipes remplies
    if (equipesFull.length < 2) {
        io.emit('error-lancement', 'Il faut au moins 2 équipes pour jouer !');
        return;
    }

    // verif desequilibre
    const size = equipesFull.map(t => t.players.length);
    const max = Math.max(...size);
    const min = Math.min(...size);

    if (max - min > 3) {
        io.emit('desequilibre', gameState.teams);
        return;
    }

    gameState.status = "playing";
    io.emit('start-game', gameState);

}
//console log - on = qd évènement émis
io.on('connection', (socket) => {
    console.log('a user connected');

// Rejoindre le jeu

    //pseudo = donnée que le client envoie
    socket.on('join-game', (pseudo) => {
        gameState.players[socket.id] = {
            pseudo: pseudo,
            team: null,
            score: 0
        }
        // on emit letat du jeu au joueur
        socket.emit('update-lobby', gameState);
        // et on informe les autres
        io.emit('update-lobby', gameState);

        if(Object.keys(gameState.players).length === 2) {
            //on lance le timer 3min à minima 2 joueurs
            setTimeout(() => lancerPartie(), 3*60*1000);
        }
    });

// Rejoindre une équipe

    socket.on('join-team', (teamName) => {
        const player = gameState.players[socket.id];
        //verif le nom
        const team = gameState.teams.find(t => t.name === teamName);

        //si le player n'existe pas
        if (!player) return;
        // et la team
        if (!team) return;

        // si joueur est deja dans une equipe
        if (player.team !== null) return;

        //maj team joueur
        player.team = teamName;
        //ajouter le joueur dans l'équipe
        team.players.push(socket.id);
        //nom de l'event que l front ecoute + donnée à envoyer au front
        io.emit('update-lobby', gameState);

    })

    socket.on('disconnect', () => {
        const player = gameState.players[socket.id];
        if(!player) return;

        if(player.team !== null){
            const team = gameState.teams.find(t => t.name === player.team);
            if(team) {
                team.players = team.players.filter(id => id !== socket.id);
            }
        }

        delete gameState.players[socket.id];
        io.emit('update-lobby', gameState);
        console.log('user disconnected');
    });
});

// lancement serveur
server.listen(port, () => {
    console.log(`Le serveur est lancé sur http://localhost:${port}`);
});