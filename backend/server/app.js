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

//console log - on = qd évènement émis
io.on('connection', (socket) => {
    console.log('a user connected');
    //give client random username
    socket.username = "User" + Math.ceil(Math.random() * 100);

    socket.on('disconnect', (socket) => {
        console.log('user disconnected');
    });
});

// lancement serveur
server.listen(port, () => {
    console.log(`Le serveur est lancé sur http://localhost:${port}`);
});