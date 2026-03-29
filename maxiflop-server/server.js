const express = require('express');
const { createServer } = require('node:http');
const { join } = require('node:path');
const { Server } = require('socket.io');
const os = require('os');
const localtunnel = require('localtunnel');

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

let godotHost = null;
let publicUrl = null;

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

function verifierEquilibrage() {
	//prendre les équipes qui ont a minima 1 joueur respectivement
	const equipesActives = gameState.teams.filter(t => t.players.length > 0);
	if (equipesActives.length < 2) {
		io.emit('error-lancement', 'Il faut au moins 2 équipes actives pour jouer !');
		return false;
	}

	//prendre le nombre de joueur de chaque équipe active
	const size = equipesActives.map(t => t.players.length);
	const max = Math.max(...size);
	const min = Math.min(...size);

	//si la différence entre le nombre de joueur de l'équipe la plus nombreuse et l'équipe la moins nombreuse est sup à 3, on lance une erreur
	if (max - min > 3) {
		io.emit('desequilibre', gameState.teams);
		return false;
	}

	return true;
}

io.on('connection', (socket) => {
	console.log('user connected :', socket.id);

	socket.on('host_join', () => {
		console.log('Godot Host connecté via Socket.IO !');
		godotHost = socket;
		sendLobbyToGodot();
		if (publicUrl) godotHost.emit('public_url', { url: publicUrl });
	});

	// Écoute de Godot
	socket.on('host_phase', (data) => {
		// data: { phase: "lobby", "countdown", "playing", "ended" }

		if (data.phase === "countdown" || data.phase === "playing") {
			if (!verifierEquilibrage()) {
				// l'equilibrage est refusé on prévient les téléphones avec des erreurs
				return;
			}
		}

		io.emit('host_phase', data);

		if (data.phase === "playing") {
			gameState.status = "playing";
		} else if (data.phase === "lobby" || data.phase === "ended") {
			gameState.status = "lobby";
		}
	});

	socket.on('join-game', (pseudo) => {
		gameState.players[socket.id] = { pseudo, team: null, score: 0 };
		io.emit('update-lobby', gameState);
		sendLobbyToGodot();
	});

	socket.on('get_lobby', () => {
		if (socket === godotHost) {
			sendLobbyToGodot();
		}
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
	});
});

server.listen(port, "0.0.0.0", async () => {
	console.log(`\nLocal: http://localhost:${port}`);
	const ifaces = os.networkInterfaces();
	for (let dev in ifaces) {
		ifaces[dev].forEach((d) => {
			if (d.family === 'IPv4' && !d.internal) console.log(`Wifi:  http://${d.address}:${port}`);
		});
	}
	console.log();

	try {
		const tunnel = await localtunnel({ port: port });
		publicUrl = tunnel.url;
		console.log(`Tunnel public: ${tunnel.url}`);
		if (godotHost) godotHost.emit('public_url', { url: publicUrl });
		tunnel.on('close', () => console.log('Tunnel fermé.'));
	} catch (e) {
		console.log("Erreur tunnel:", e.message);
	}
});
