const btnParticiper = document.getElementById('btnPart');
const sectionLogin = document.getElementById('login');
const sectionAttente = document.getElementById('attente');
const inputPseudo = document.getElementById('ajout-pseudo');
const sectionJeu = document.getElementById('jeu');
const sectionEquipe = document.getElementById('equipe');
const btnEquipe = document.querySelectorAll('.select-equip');
//const socket = io('');

//test ajout des eff pour voir si l'alert marche
let effectifs = { "1": 5, "2": 2, "3": 4 };

btnParticiper.addEventListener('click', () => {
    const pseudo = inputPseudo.value;
    if(pseudo.trim() !== ""){
        console.log("Pseudo choisi :", pseudo);
        sectionLogin.classList.add('arriere');
        sectionEquipe.classList.remove('arriere');

        majCompteurs();
    } else {
        alert("Veuillez ajouter un pseudo !");
    }
});

btnEquipe.forEach(btn => {
    btn.addEventListener('click', () => {
        const teamSelect = btn.getAttribute('data-team');
        if(peutRejoindre(teamSelect)){
            console.log("Équipe rejointe :", teamSelect);
            sectionEquipe.classList.add('arriere');
            sectionAttente.classList.remove('arriere') 
        
        //test  en att avant d'avoir le serv pour accéder à la page suivante
        setTimeout(() => {
                sectionAttente.classList.add('arriere');
                sectionJeu.classList.remove('arriere');
        }, 4000);

        } else {
            alert("Les équipes ne sont pas équilibrées :( Veuillez en choisir une autre");
        }
        
    })})


function peutRejoindre(idEquipe) {
    let teamJoueurCliquer = effectifs[idEquipe];
    let listNbrJoueurParEquipe = Object.values(effectifs);
    let minActuel = Math.min(...listNbrJoueurParEquipe);
    let diff = teamJoueurCliquer - minActuel;
    if (diff >= 3) {
        return false; 
    } else {
        return true; 
    }
}

function majCompteurs() {
    for (let id in effectifs) {
        const span = document.getElementById(`cpt-${id}`);
        if (span) {
            span.textContent = effectifs[id];
        }
    }
}
/*
socket.on("signal", () => {
    document.getElementById('attente').classList.add('arriere');
    document.getElementById('jeu').classList.remove('arriere');
});
*/