const express = require('express');
const { createServer } = require('node:http');
const { join } = require('node:path');
const { Server } = require('socket.io');
const os = require('os');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');


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
	players: {},
	teamScores: { "Equipe1": 0, "Equipe2": 0, "Equipe3": 0 },
	availableMusics: [],
	playerVotes: {}, // socket.id -> songName
	gameMode: "NORMAL"
};

let godotHost = null;
let publicUrl = null;
let cloudflaredProcess = null;

function cleanupAndExit() {
	console.log("\nArrêt du serveur et nettoyage...");
	if (cloudflaredProcess) {
		console.log("Fermeture du tunnel Cloudflare...");
		cloudflaredProcess.kill();
	}
	process.exit(0);
}

// Gestion des signaux d'arrêt
process.on('SIGINT', cleanupAndExit);
process.on('SIGTERM', cleanupAndExit);

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

	const teamScores = { ...gameState.teamScores };

	godotHost.emit("lobby_update", {
		players: playersArr,
		teamScores: teamScores,
		publicUrl: publicUrl
	});
}

function remoteLog(msg) {
	const timestamp = new Date().toISOString();
	const logLine = `[${timestamp}] ${msg}\n`;
	console.log(`[REMOTE] ${msg}`);
	
	// Écrire dans un fichier accessible par l'IA dans godot-src
	try {
		const logPath = path.join(__dirname, '../maxiflop-src/server_debug_log.txt');
		fs.appendFileSync(logPath, logLine);
	} catch (e) {
		console.error("Erreur ecriture log:", e);
	}

	io.emit("server_debug", msg);
}

function sendVoteStatsToGodot() {
	if (gameState.status !== "voting") return;

	const tally = {};
	const totalVotes = Object.keys(gameState.playerVotes).length;
	
	if (totalVotes === 0) {
		io.emit("vote_update", []);
		return;
	}

	Object.values(gameState.playerVotes).forEach(song => {
		tally[song] = (tally[song] || 0) + 1;
	});

	const sortedStats = Object.keys(tally)
		.map(songName => ({
			songName,
			votes: tally[songName],
			percentage: Math.round((tally[songName] / totalVotes) * 100)
		}))
		.sort((a, b) => b.votes - a.votes)
		.slice(0, 3); // Top 3

	io.emit("vote_update", sortedStats);
}

function sendPlayerLeftToGodot(id) {
	if (godotHost) godotHost.emit("player_left", { playerId: id });
}

function sendLobbyToClients() {
	io.emit('update-lobby', gameState);
}

function verifierEquilibrage() {
	const size = gameState.teams.map(t => t.players.length);
	const nbActives = size.filter(s => s > 0).length;

	if (nbActives < 1) {
		io.emit('error-lancement', 'Il faut au moins 1 joueur pour jouer !');
		return false;
	}

	const max = Math.max(...size);
	const min = Math.min(...size);

	//si la différence entre le nombre de joueur de l'équipe la plus nombreuse et l'équipe la moins nombreuse est sup à 2, on lance une erreur
	if (max - min > 2) {
		io.emit('desequilibre', gameState.teams);
		return false;
	}

	return true;
}

io.on('connection', (socket) => {
	console.log('user connected :', socket.id);
	socket.emit('update-lobby', gameState);

	socket.on('host_join', () => {
		console.log('Godot Host connecté via Socket.IO !');
		godotHost = socket;
		remoteLog("SYSTEM ONLINE - Ready to process votes.");
		
		// Si l'URL publique est déjà prête, on l'envoie tout de suite
		if (publicUrl) {
			console.log("[Cloudflare] Envoi de l'URL publique existante à l'hôte Godot...");
			godotHost.emit('public_url', { url: publicUrl });
		}
		
		sendLobbyToGodot();
	});

	socket.onAny((event, ...args) => {
		if (event !== "player_input") { // Éviter de logguer le spam de gameplay
			console.log(`[RAW PACKET] from ${socket.id}: event=${event}, args=${JSON.stringify(args)}`);
		}
	});

	// Écoute de Godot
	socket.on('host_phase', (data) => {
		// data: { phase: "lobby", "countdown", "playing", "ended", gameMode: "NORMAL" }
		remoteLog(`Phase changed to: ${data.phase} (${data.gameMode || 'NORMAL'})`);

		// CRITIQUE : On met à jour l'état INTERNE avant de broadcaster aux clients
		gameState.gameMode = data.gameMode || "NORMAL";
		
		if (gameState.status === "voting" && data.phase !== "voting") {
			// Fin du vote, calculer le gagnant en agrégeant playerVotes
			const tally = {};
			Object.values(gameState.playerVotes).forEach(song => {
				tally[song] = (tally[song] || 0) + 1;
			});

			let winner = "";
			let maxVotes = -1;
			Object.keys(tally).forEach(song => {
				if (tally[song] > maxVotes) {
					maxVotes = tally[song];
					winner = song;
				}
			});
			// Si pas de vote, prendre une musique au hasard
			if (!winner && gameState.availableMusics.length > 0) {
				winner = gameState.availableMusics[Math.floor(Math.random() * gameState.availableMusics.length)];
			}
			remoteLog(`VOTE Ended. Winner: ${winner}`);
			io.emit('vote_result', { winner });
		} else if (data.phase === "voting") {
			if (gameState.status !== "voting") {
				gameState.status = "voting";
				gameState.playerVotes = {};
				remoteLog(`VOTE Started. Ready for ${gameState.availableMusics.length} musics.`);
			} else {
				remoteLog(`VOTE Phase re-broadcast (already voting). Keeping votes.`);
			}
			sendVoteStatsToGodot(); // Reset stats envoi []
		} else if (data.phase === "reveal" || data.phase === "countdown") {
			gameState.status = data.phase;
		} else if (data.phase === "lobby" || data.phase === "ended") {
			gameState.status = "lobby";
		}

		// Maintenant on prévient les clients
		io.emit('host_phase', data);
	});

	socket.on('player_eliminated', (data) => {
		// data: { playerId: "socketId" }
		if (data.playerId) {
			console.log(`Joueur éliminé : ${data.playerId}`);
			io.to(data.playerId).emit('eliminated', { status: true });
		}
	});

	socket.on('join-game', (pseudo) => {
		gameState.players[socket.id] = { pseudo, team: 'Equipe1', score: 0 };
		sendLobbyToClients();
		sendLobbyToGodot();
	});

	// Envoyer l'état actuel uniformisé immédiatement à la connexion
	sendLobbyToClients();

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

	socket.on('scoreboard', (data) => {
		if (data.players) {
			data.players.forEach(p => {
				if (gameState.players[p.id]) {
					gameState.players[p.id].score = p.score;
					gameState.players[p.id].combo = p.combo;
					gameState.players[p.id].perfect_streak = p.perfect_streak;
				}
			});
		}
		if (data.teamScores) {
			Object.assign(gameState.teamScores, data.teamScores);
		}
	});

	socket.on('music_list', (data) => {
		gameState.availableMusics = data.musics || [];
		io.emit('music_list', gameState.availableMusics);
	});

	socket.on('vote', (data) => {
		const songName = data.songName;
		
		if (gameState.status !== "voting") {
			remoteLog(`VOTE REJECTED: Server is in status "${gameState.status}"`);
			return;
		}

		if (!gameState.availableMusics || gameState.availableMusics.length === 0) {
			remoteLog(`VOTE REJECTED: No musics loaded.`);
			return;
		}

		// Validation relaxée et logging détaillé
		const cleanVote = songName.trim();
		const match = gameState.availableMusics.find(m => m.trim().toLowerCase() === cleanVote.toLowerCase());

		if (match) {
			gameState.playerVotes[socket.id] = match;
			remoteLog(`VOTE SUCCESS from ${socket.id.substring(0,4)}: -> ${match}`);
			sendVoteStatsToGodot();
		} else {
			remoteLog(`VOTE FAILED: "${songName}" not in list.`);
			// Fallback : on accepte quand même pour débloquer l'affichage si c'est un bug de nom
			gameState.playerVotes[socket.id] = songName;
			sendVoteStatsToGodot();
		}
	});

	socket.on('disconnect', () => {
		console.log('user disconnected :', socket.id);

		if (godotHost === socket) {
			console.log('Godot Host déconnecté, AUTO-DESTRUCTION du serveur Node.');
			godotHost = null;
			cleanupAndExit();
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

const cloudflared = require('cloudflared');

server.listen(port, "0.0.0.0", async () => {
	console.log(`\nLocal: http://localhost:${port}`);
	console.log("Système :", os.platform(), os.arch());
	console.log("Node Executable :", process.execPath);
	
	const ifaces = os.networkInterfaces();
	for (let dev in ifaces) {
		ifaces[dev].forEach((d) => {
			if (d.family === 'IPv4' && !d.internal) console.log(`Wifi:  http://${d.address}:${port}`);
		});
	}
	console.log();

	try {
		console.log("Démarrage du tunnel Cloudflare (Binaire direct)...");
		
		const bin = cloudflared.bin;
		const tunnelArgs = ['tunnel', '--url', `http://127.0.0.1:${port}`];
		
		console.log(`[Cloudflare] Commande : ${bin} ${tunnelArgs.join(' ')}`);
		
		cloudflaredProcess = spawn(bin, tunnelArgs);

		let outputBuffer = '';
		const handleTunnelOutput = (data) => {
			const str = data.toString();
			outputBuffer += str;
			
			// Filtrage des logs pour la console
			if (str.includes("INF") || str.includes("ERR") || str.includes("https://")) {
				process.stdout.write("[Cloudflare] " + str);
			}

			const match = outputBuffer.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
			if (match && !publicUrl) {
				publicUrl = match[0];
				console.log(`\n=== TUNNEL PRÊT ===\nURL publique: ${publicUrl}\n===================\n`);
				
				if (godotHost) {
					console.log("[Cloudflare] Envoi de l'URL à l'Hôte Godot.");
					godotHost.emit('public_url', { url: publicUrl });
				}
			}
		};

		cloudflaredProcess.stdout.on('data', handleTunnelOutput);
		cloudflaredProcess.stderr.on('data', handleTunnelOutput);

		cloudflaredProcess.on('close', (code) => {
			console.log(`Le tunnel Cloudflare s'est fermé avec le code ${code}`);
			cloudflaredProcess = null;
		});

		cloudflaredProcess.on('error', (err) => {
			console.log("Erreur critique Cloudflare :", err.message);
		});

	} catch (e) {
		console.log("Erreur de lancement Cloudflare :", e.message);
	}
});
