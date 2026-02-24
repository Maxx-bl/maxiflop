const btnParticiper = document.getElementById('btnPart');
const sectionLogin = document.getElementById('login');
const sectionAttente = document.getElementById('attente');
const inputPseudo = document.getElementById('ajout-pseudo');

btnParticiper.addEventListener('click', () => {
    const pseudo = inputPseudo.value;
    if(pseudo.trim() !== ""){
        console.log("Pseudo choisi :", pseudo);
        sectionLogin.classList.add('arriere');
        sectionAttente.classList.remove('arriere');
    } else {
        alert("Veuillez ajouter un pseudo !");
    }
});