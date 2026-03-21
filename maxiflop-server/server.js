const path = require("path");
const express = require("express");
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT || 8080);
const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: "/ws" });

const smartphonePath = path.join(__dirname, "..", "maxiflop-smartphone");
app.use(express.static(smartphonePath));

let hostSocket = null;
const players = new Map();
const socketsToPlayers = new Map();
let gamePhase = "lobby";

const randomTeam = () => (Math.random() < 0.5 ? "A" : "B");
const wsSend = (socket, payload) => {
	if (!socket || socket.readyState !== 1) return;
	socket.send(JSON.stringify(payload));
};

const buildPlayersPayload = () =>
	Array.from(players.values()).map((p) => ({
		id: p.id,
		name: p.name,
		team: p.team,
		score: p.score,
		combo: p.combo
	}));

const computeTeamScores = () => {
	const teamScores = { A: 0, B: 0 };
	for (const p of players.values()) {
		teamScores[p.team] += p.score;
	}
	return teamScores;
};

const notifyHostLobby = () => {
	wsSend(hostSocket, {
		type: "lobby_update",
		players: buildPlayersPayload(),
		teamScores: computeTeamScores()
	});
};

wss.on("connection", (socket) => {
	socket.on("message", (raw) => {
		let msg = null;
		try {
			msg = JSON.parse(raw.toString());
		} catch {
			return;
		}

		if (msg.type === "host_join") {
			hostSocket = socket;
			notifyHostLobby();
			return;
		}

		if (msg.type === "player_join") {
			const id = `p_${Math.random().toString(36).slice(2, 10)}`;
			const player = {
				id,
				name: String(msg.name || "Player").slice(0, 15),
				team: randomTeam(),
				score: 0,
				combo: 0,
				socket
			};
			players.set(id, player);
			socketsToPlayers.set(socket, id);
			wsSend(socket, { type: "joined", playerId: id, team: player.team });
			wsSend(socket, { type: "phase", phase: gamePhase });
			notifyHostLobby();
			return;
		}

		if (msg.type === "player_input") {
			const playerId = socketsToPlayers.get(socket);
			if (!playerId || !hostSocket) return;
			wsSend(hostSocket, {
				type: "player_input",
				playerId,
				color: Number(msg.color),
				clientTs: Number(msg.clientTs || Date.now()),
				serverTs: Date.now()
			});
			return;
		}

		if (msg.type === "host_phase") {
			gamePhase = String(msg.phase || "lobby");
			for (const p of players.values()) {
				wsSend(p.socket, { type: "phase", phase: gamePhase });
			}
			return;
		}

		if (msg.type === "feedback") {
			const playerId = String(msg.playerId || "");
			const player = players.get(playerId);
			if (!player) return;

			player.score = Number(msg.score || player.score);
			player.combo = Number(msg.combo || player.combo);
			wsSend(player.socket, {
				type: "feedback",
				result: String(msg.result || "MISS"),
				points: Number(msg.points || 0),
				score: player.score,
				combo: player.combo,
				rank: Number(msg.rank || 1)
			});
			return;
		}

		if (msg.type === "scoreboard") {
			const incomingPlayers = Array.isArray(msg.players) ? msg.players : [];
			for (const p of incomingPlayers) {
				const id = String(p.id || "");
				if (!players.has(id)) continue;
				const stored = players.get(id);
				stored.score = Number(p.score || stored.score);
				stored.combo = Number(p.combo || stored.combo);
				players.set(id, stored);
			}
			notifyHostLobby();
		}
	});

	socket.on("close", () => {
		if (socket === hostSocket) {
			hostSocket = null;
		}

		const playerId = socketsToPlayers.get(socket);
		if (!playerId) return;

		socketsToPlayers.delete(socket);
		players.delete(playerId);

		wsSend(hostSocket, { type: "player_left", playerId });
		notifyHostLobby();
	});
});

server.listen(PORT, "0.0.0.0", () => {
	console.log(`MAXIFLOP server running on http://0.0.0.0:${PORT}`);
	console.log("Open this URL on smartphone by QR code or manually.");
});
