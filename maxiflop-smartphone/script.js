const joinButton = document.getElementById("joinButton");
const nameInput = document.getElementById("nameInput");
const statusText = document.getElementById("status");
const teamInfo = document.getElementById("teamInfo");
const scoreText = document.getElementById("scoreText");
const rankText = document.getElementById("rankText");
const feedbackText = document.getElementById("feedback");

const screens = {
	login: document.getElementById("login"),
	waiting: document.getElementById("waiting"),
	controller: document.getElementById("controller")
};

let ws = null;
let joined = false;
let playerTeamLabel = "bleue";
let reconnectTimer = null;
let playerName = "";

const showScreen = (key) => {
	Object.values(screens).forEach((el) => el.classList.add("hidden"));
	screens[key].classList.remove("hidden");
};

const getWsUrl = () => {
	const protocol = window.location.protocol === "https:" ? "wss" : "ws";
	return `${protocol}://${window.location.host}/ws`;
};

const sendJson = (payload) => {
	if (!ws || ws.readyState !== WebSocket.OPEN) return;
	ws.send(JSON.stringify(payload));
};

const connectSocket = (name) => {
	playerName = name;
	localStorage.setItem("maxiflop_name", name);
	ws = new WebSocket(getWsUrl());

	ws.addEventListener("open", () => {
		statusText.textContent = "Connexion etablie";
		sendJson({ type: "player_join", name });
		if (reconnectTimer) {
			clearTimeout(reconnectTimer);
			reconnectTimer = null;
		}
	});

	ws.addEventListener("close", () => {
		statusText.textContent = "Connexion perdue, reconnexion...";
		reconnectTimer = setTimeout(() => {
			const cached = playerName || localStorage.getItem("maxiflop_name") || "";
			if (cached.trim()) {
				connectSocket(cached);
			}
		}, 1500);
	});

	ws.addEventListener("message", (event) => {
		let msg = null;
		try {
			msg = JSON.parse(event.data);
		} catch (e) {
			return;
		}
		handleServerMessage(msg);
	});
};

const handleServerMessage = (msg) => {
	if (!msg || !msg.type) return;

	if (msg.type === "joined") {
		joined = true;
		playerTeamLabel = msg.teamLabel || (msg.team === "A" ? "bleue" : "rouge");
		teamInfo.textContent = `Equipe ${playerTeamLabel} - en attente du lancement`;
		rankText.textContent = `Rang #1 - Equipe ${playerTeamLabel}`;
		rankText.className = msg.team === "A" ? "team-blue" : "team-red";
		showScreen("waiting");
		return;
	}

	if (msg.type === "phase") {
		if (msg.phase === "lobby" || msg.phase === "warmup" || msg.phase === "countdown") {
			showScreen("waiting");
			const remain = Number(msg.remaining || 0);
			if (msg.phase === "warmup" && remain > 0) {
				teamInfo.textContent = `Equipe ${playerTeamLabel} - debut dans ${remain}s`;
			} else if (msg.phase === "countdown") {
				teamInfo.textContent = `Equipe ${playerTeamLabel} - prepare-toi`;
			} else {
				teamInfo.textContent = `Equipe ${playerTeamLabel} - en attente du lancement`;
			}
		}
		if (msg.phase === "playing" && joined) {
			feedbackText.textContent = "GO !";
			document.body.classList.add("playing");
			showScreen("controller");
		}
		if (msg.phase === "ended") {
			document.body.classList.remove("playing");
			showScreen("waiting");
			teamInfo.textContent = "Partie terminee. En attente de la suivante.";
		}
		return;
	}

	if (msg.type === "feedback") {
		feedbackText.textContent = `${msg.result} (+${msg.points})`;
		scoreText.textContent = `${msg.score}`;
		rankText.textContent = `Rang #${msg.rank} - Equipe ${playerTeamLabel}`;
		triggerFeedback(msg.result);
		return;
	}
};

joinButton.addEventListener("click", () => {
	const name = nameInput.value.trim();
	if (!name) {
		statusText.textContent = "Entrez un pseudo";
		return;
	}
	statusText.textContent = "Connexion au serveur...";
	connectSocket(name);
});

const savedName = localStorage.getItem("maxiflop_name");
if (savedName) {
	nameInput.value = savedName;
}

document.querySelectorAll(".btn").forEach((btn) => {
	btn.addEventListener("pointerdown", () => {
		const color = Number(btn.dataset.color);
		sendJson({
			type: "player_input",
			color,
			clientTs: Date.now()
		});
		// Vibration courte à chaque pression
		if (navigator.vibrate) navigator.vibrate(40);
	});
});

// Feedback visuel + haptique selon le résultat
const resultStyles = {
	"PERFECT": { bg: "#84FFC9", vibrate: [60, 30, 60], textColor: "#0a2a1a" },
	"GOOD":    { bg: "#AAB2FF", vibrate: [30],          textColor: "#0a0a2a" },
	"BAD":     { bg: "#F0E040", vibrate: [20],          textColor: "#1a1800" },
	"MISS":    { bg: "#FF7081", vibrate: [80],          textColor: "#1a0005" },
};

let flashTimeout = null;
const controllerScreen = document.getElementById("controller");

function triggerFeedback(result) {
	const style = resultStyles[result];
	if (!style) return;

	// Vibration haptique
	if (navigator.vibrate) navigator.vibrate(style.vibrate);

	// Flash de fond
	if (flashTimeout) clearTimeout(flashTimeout);
	controllerScreen.style.backgroundColor = style.bg;
	controllerScreen.style.transition = "background-color 0ms";
	flashTimeout = setTimeout(() => {
		controllerScreen.style.transition = "background-color 400ms ease-out";
		controllerScreen.style.backgroundColor = "";
	}, result === "PERFECT" ? 180 : 80);
}