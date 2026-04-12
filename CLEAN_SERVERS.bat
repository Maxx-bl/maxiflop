@echo off
echo =================================_________=================================
echo Nettoyage des processus MAXIFLOP (Node.js et Cloudflare)
echo ==========================================_________========================
taskkill /F /IM node.exe /T 2>nul
taskkill /F /IM cloudflared.exe /T 2>nul
echo.
echo Nettoyage termine. Vous pouvez relancer le jeu !
pause
