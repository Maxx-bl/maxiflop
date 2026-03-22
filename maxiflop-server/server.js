const express = require('express');
const { createServer } = require('node:http');
const { join } = require('node:path');
const { Server } = require('socket.io');
const os = require('os');

const app = express();
const server = createServer(app);
const io = new Server(server, { cors: { origin: "*" } });
const port = 3000;

app.use(express.static(join(__dirname, '../maxiflop-smartphone')));
app.get('/', (req, res) => res.sendFile(join(__dirname, '../maxiflop-smartphone/index.html')));

const gameState = {
	status: "lobby",
	teams: [
		{ name: "Equipe1", players: [] },
		{ name: "Equipe2", players: [] },
		{ name: "Equipe3", players: [] }
	],
	players: {}
};

let countdownInterval = null;
let tempsRestant = 15;
let godotHost = null;

function sendLobbyToGodot() {
	if (!godotHost) return;

	const playersArr = [];
	Object.keys(gameState.players).forEach(id => {
		playersArr.push({
			id: id,
			pseudo: gameState.players[id].pseudo,
			team: gameState.players[id].team
		});
	});

	const teamScores = {};
	gameState.teams.forEach(t => teamScores[t.name] = 0);

	godotHost.emit("lobby_update", {
		players: playersArr,
		teamScores: teamScores
	});
}

function sendPlayerLeftToGodot(id) {
	if (godotHost) godotHost.emit("player_left", { playerId: id });
}

function lancerPartie() {
	const equipesActives = gameState.teams.filter(t => t.players.length > 0);
	if (equipesActives.length < 2) {
		io.emit('error-lancement', 'Il faut au moins 2 équipes actives pour jouer !');
		return false;
	}

	const size = equipesActives.map(t => t.players.length);
	const max = Math.max(...size);
	const min = Math.min(...size);

	if (max - min > 3) {
		io.emit('desequilibre', gameState.teams);
		return false;
	}

	gameState.status = "playing";
	io.emit('start-game', gameState);
	return true;
}

function demarrerChrono() {
	if (Object.keys(gameState.players).length >= 2 && !countdownInterval) {
		tempsRestant = 15;
		io.emit('timer-tick', tempsRestant);

		countdownInterval = setInterval(() => {
			tempsRestant--;
			io.emit('timer-tick', tempsRestant);

			if (tempsRestant <= 0) {
				if (!lancerPartie()) {
					tempsRestant = 10;
					io.emit('timer-tick', tempsRestant);
				} else {
					clearInterval(countdownInterval);
					countdownInterval = null;
				}
			}
		}, 1000);
	}
}

function stopperChrono() {
	if (Object.keys(gameState.players).length < 2 && countdownInterval) {
		clearInterval(countdownInterval);
		countdownInterval = null;
		io.emit('timer-tick', -1);
	}
}

io.on('connection', (socket) => {
	console.log('user connected :', socket.id);

	socket.on('host_join', () => {
		console.log('Godot Host connecté via Socket.IO !');
		godotHost = socket;
		sendLobbyToGodot();
	});

	socket.on('join-game', (pseudo) => {
		gameState.players[socket.id] = { pseudo, team: null, score: 0 };
		io.emit('update-lobby', gameState);
		sendLobbyToGodot();
		demarrerChrono();
	});

	socket.on('join-team', (teamName) => {
		const player = gameState.players[socket.id];
		const team = gameState.teams.find(t => t.name === teamName);
		if (!player || !team) return;

		if (player.team) {
			const oldTeam = gameState.teams.find(t => t.name === player.team);
			if (oldTeam) oldTeam.players = oldTeam.players.filter(id => id !== socket.id);
		}

		player.team = teamName;
		team.players.push(socket.id);
		io.emit('update-lobby', gameState);
		sendLobbyToGodot();
	});

	socket.on('player_input', (data) => {
		io.emit('player_input', {
			playerId: socket.id,
			color: Number(data.color),
			clientTs: Number(data.clientTs || Date.now()),
			serverTs: Date.now()
		});

		if (godotHost) {
			godotHost.emit('player_input', {
				playerId: socket.id,
				color: Number(data.color),
				clientTs: Number(data.clientTs || Date.now()),
				serverTs: Date.now()
			});
		}
	});

	socket.on('feedback', (data) => {
		if (data.playerId) io.to(data.playerId).emit('feedback', data);
	});

	socket.on('disconnect', () => {
		console.log('user disconnected :', socket.id);

		if (godotHost === socket) {
			console.log('Godot Host déconnecté');
			godotHost = null;
			return;
		}

		const player = gameState.players[socket.id];
		if (!player) return;

		if (player.team) {
			const team = gameState.teams.find(t => t.name === player.team);
			if (team) team.players = team.players.filter(id => id !== socket.id);
		}

		delete gameState.players[socket.id];
		io.emit('update-lobby', gameState);
		sendPlayerLeftToGodot(socket.id);
		sendLobbyToGodot();
		stopperChrono();
	});
});

server.listen(port, "0.0.0.0", () => {
	console.log(`\nLocal: http://localhost:${port}`);
	const ifaces = os.networkInterfaces();
	for (let dev in ifaces) {
		ifaces[dev].forEach((d) => {
			if (d.family === 'IPv4' && !d.internal) console.log(`Wifi:  http://${d.address}:${port}`);
		});
	}
	console.log();
});
