const nameInput = document.getElementById("nameInput");
const statusText = document.getElementById("status");
const teamInfo = document.getElementById("teamInfo");
const scoreText = document.getElementById("scoreText");
const rankText = document.getElementById("rankText");
const feedbackText = document.getElementById("feedback");
const timerDisplay = document.getElementById("timerDisplay");

const screens = {
	login: document.getElementById("login"),
	waiting: document.getElementById("waiting"),
	controller: document.getElementById("controller")
};

const showScreen = (key) => {
	Object.values(screens).forEach((el) => el.classList.add("hidden"));
	screens[key].classList.remove("hidden");
};

const socket = io();

document.querySelectorAll(".join-team-btn").forEach((btn) => {
	btn.addEventListener("click", () => {
		const teamName = btn.dataset.team;
		joinGame(teamName);
	});
});

function joinGame(teamName) {
	const name = nameInput.value.trim();
	if (!name) {
		statusText.textContent = "Entrez un pseudo d'abord !";
		return;
	}

	statusText.textContent = "Connexion...";
	localStorage.setItem("maxiflop_name", name);

	socket.emit("join-game", name);

	setTimeout(() => {
		socket.emit("join-team", teamName);
		showScreen("waiting");
	}, 100);
}

socket.on("update-lobby", (gameState) => {
	const myPlayer = gameState.players[socket.id];
	if (!myPlayer || !myPlayer.team) return;

	teamInfo.textContent = `Tu es dans l'${myPlayer.team} !`;
	rankText.textContent = `Rang #1 - ${myPlayer.team}`;
	
	if (myPlayer.team === "Equipe1") rankText.className = "team-blue";
	else if (myPlayer.team === "Equipe2") rankText.className = "team-red";
	else rankText.className = "team-yellow";
});

// Écoute du chrono précis envoyé par le serveur
socket.on("timer-tick", (timeLeft) => {
    if (timeLeft < 0) {
        timerDisplay.textContent = "En attente d'autres joueurs...";
    } else {
        timerDisplay.textContent = `Lancement dans ${timeLeft} s...`;
    }
});

socket.on("start-game", (gameState) => {
	feedbackText.textContent = "GO !";
	document.body.classList.add("playing");
	showScreen("controller");
});

socket.on("error-lancement", (msg) => {
	alert("Erreur de lancement : " + msg);
});

socket.on("desequilibre", (teams) => {
	alert("Équipes déséquilibrées ! Il faut s'équilibrer pour que la partie puisse démarrer.");
});

socket.on("feedback", (msg) => {
	feedbackText.textContent = `${msg.result} (+${msg.points})`;
	scoreText.textContent = `${msg.score}`;
	triggerFeedback(msg.result);
});

document.querySelectorAll(".btn[data-color]").forEach((btn) => {
	btn.addEventListener("pointerdown", (e) => {
		e.preventDefault();
		const color = Number(btn.dataset.color);
		socket.emit("player_input", {
			color,
			clientTs: Date.now()
		});
		if (navigator.vibrate) navigator.vibrate(40);
	});
});

const resultStyles = {
	"PERFECT": { bg: "#84FFC9", vibrate: [60, 30, 60], textColor: "#0a2a1a" },
	"GOOD": { bg: "#AAB2FF", vibrate: [30], textColor: "#0a0a2a" },
	"BAD": { bg: "#F0E040", vibrate: [20], textColor: "#1a1800" },
	"MISS": { bg: "#FF7081", vibrate: [80], textColor: "#1a0005" },
};

let flashTimeout = null;
const controllerScreen = document.getElementById("controller");

function triggerFeedback(result) {
	const style = resultStyles[result];
	if (!style) return;

	if (navigator.vibrate) navigator.vibrate(style.vibrate);
	if (flashTimeout) clearTimeout(flashTimeout);

	controllerScreen.style.backgroundColor = style.bg;
	controllerScreen.style.transition = "background-color 0ms";

	flashTimeout = setTimeout(() => {
		controllerScreen.style.transition = "background-color 400ms ease-out";
		controllerScreen.style.backgroundColor = "";
	}, result === "PERFECT" ? 180 : 80);
}

const savedName = localStorage.getItem("maxiflop_name");
if (savedName) {
	nameInput.value = savedName;
}