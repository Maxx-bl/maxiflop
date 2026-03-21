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
	ws = new WebSocket(getWsUrl());

	ws.addEventListener("open", () => {
		statusText.textContent = "Connexion etablie";
		sendJson({ type: "player_join", name });
	});

	ws.addEventListener("close", () => {
		statusText.textContent = "Connexion perdue. Rechargez la page.";
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
		teamInfo.textContent = `Equipe ${msg.team} - en attente du lancement`;
		showScreen("waiting");
		return;
	}

	if (msg.type === "phase") {
		if (msg.phase === "playing" && joined) {
			feedbackText.textContent = "GO !";
			showScreen("controller");
		}
		if (msg.phase === "ended") {
			showScreen("waiting");
			teamInfo.textContent = "Partie terminee. En attente de la suivante.";
		}
		return;
	}

	if (msg.type === "feedback") {
		feedbackText.textContent = `${msg.result} (+${msg.points})`;
		scoreText.textContent = `Score: ${msg.score}`;
		rankText.textContent = `Rang: #${msg.rank}`;
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

document.querySelectorAll(".btn").forEach((btn) => {
	btn.addEventListener("click", () => {
		const color = Number(btn.dataset.color);
		sendJson({
			type: "player_input",
			color,
			clientTs: Date.now()
		});
	});
});