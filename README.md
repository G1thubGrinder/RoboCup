# ⚽ RoboCup Demo Visualizer

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![Language](https://img.shields.io/badge/language-Prolog%20%7C%20Javascript-orange)

This project demonstrates a RoboCup simulation using **SWI-Prolog** and provides a web-based visualizer for the generated game data.

---

## 📌 Overview
The workflow of this project is:
1. Run the Prolog simulation to generate match data
2. Start a local web server
3. Open the visualizer in your browser

---

## ⚙️ Prerequisites
Make sure you have the following installed:

- [SWI-Prolog](https://www.swi-prolog.org/)
- Python 3

---

## 🚀 Getting Started

### 1️⃣ Generate Game Log
Consult robocup.pl file

``` prolog
consult(['PATH_TO_THE_FILE']).
```
Run the simulation
```prolog
round_simulation(10).
```
This command will generate the match that play for 10 goals. The file **game_log.json** will be exported automatically inside the same directory after this command is executed.

### 2️⃣ Start local server
Windows
```cmd or windows-powershell
run.bat
```
MacOS and Linux
```bash
chmod +x run.sh
./run.sh
```

### 3️⃣ Open Visualizer
After starting the server, you will see a message like:
```
Starting demo server at http://localhost:8080/app/visualizer.html
```
Open the link in your browser to view the simulation.
