#!/usr/bin/env bash
# run.sh — Run RoboCup simulation and open the visualizer
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "🔄 Running Prolog simulation..."
/Applications/SWI-Prolog.app/Contents/MacOS/swipl -g start_one_round -t halt robocup.pl

echo ""
echo "✅ game_log.json generated."
echo "🌐 Starting HTTP server at http://localhost:8080/visualizer.html"
echo "   Press Ctrl+C to stop."
echo ""

# Open browser (macOS)
sleep 0.5 && open "http://localhost:8080/visualizer.html" &

python3 -m http.server 8080
