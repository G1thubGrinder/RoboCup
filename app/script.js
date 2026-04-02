// ───────────────────────────────────────────
// Config
// ───────────────────────────────────────────
const FIELD_W = 120, FIELD_H = 60;
const CANVAS_W = 960, CANVAS_H = 480;
const scaleX = CANVAS_W / FIELD_W;
const scaleY = CANVAS_H / FIELD_H;

// Team colours
const TEAM_COLORS = {
    team1: { fill: '#f0c040', stroke: '#7a5c00', label: 'Real Madrid' },
    team2: { fill: '#4a90d9', stroke: '#1a3670', label: 'Barcelona' },
};

const ROLE_SHAPE = {
    forward: 'circle',
    midfield: 'square',
    defender: 'diamond',
    goalkeeper: 'hexagon',
};

// ───────────────────────────────────────────
// State
// ───────────────────────────────────────────
let games = [];
let currentIdx = 0;
let playing = false;
let animTimer = null;
let goalBanner = { showing: false };
let selectedTime = 1;

// ───────────────────────────────────────────
// Elements
// ───────────────────────────────────────────
const canvas = document.getElementById('field');
const ctx = canvas.getContext('2d');
const btnPlay = document.getElementById('btn-play');
const btnBack = document.getElementById('btn-back');
const btnFwd = document.getElementById('btn-fwd');
const btnReset = document.getElementById('btn-reset');
const dropdown = document.getElementById('dropdown');
const timeline = document.getElementById('timeline');
const speedSlider = document.getElementById('speed');
const speedVal = document.getElementById('speed-val');
const curRoundEl = document.getElementById('cur-round');
const totalRoundsEl = document.getElementById('total-rounds');
const goalBannerEl = document.getElementById('goal-banner');
const goalTextEl = document.getElementById('goal-text');
const goalScorerEl = document.getElementById('goal-scorer');
const scoreEl = document.getElementById('score');
const tooltip = document.getElementById('tooltip');

// ───────────────────────────────────────────
// Load data
// ───────────────────────────────────────────
async function loadLog() {
    try {
        const res = await fetch('../game_log.json');
        if (!res.ok) throw new Error(res.status);
        const data = await res.json();
        games = data.games;
        init();
    } catch (e) {
        document.getElementById('field-wrapper').innerHTML =
        `<div class="loading">
        ⚠️ Could not load <code>game_log.json</code>.<br><br>
        The error is ${e}
        </div>`;
        console.log(e);
    }
}

function init() {
    timeline.max = games[0].times.length;
    console.log(games[0].times)
    timeline.value = 0;
    totalRoundsEl.textContent = games[0].times.length;
    for(let i = 1; i <= games.length; ++i){
        let option = document.createElement("option");
        option.value = i;
        option.text = i;
        dropdown.appendChild(option)
    }
    drawTimeFrame(1,1);
}

// ───────────────────────────────────────────
// Goal detection
// ───────────────────────────────────────────
function checkGoal(ball) {
    if (ball.x >= 120 && ball.y >= 27 && ball.y <= 33) {
        showGoal('⚽ GOAL!', '🏆 Real Madrid scores!', '#f0c040');
        scoreEl.textContent = '1 – 0';
    } else if (ball.x <= 0 && ball.y >= 27 && ball.y <= 33) {
        showGoal('⚽ GOAL!', '🏆 Barcelona scores!', '#4a90d9');
        scoreEl.textContent = '0 – 1';
    }
}

function showGoal(text, scorer, color) {
    goalTextEl.textContent = text;
    goalTextEl.style.color = color;
    goalScorerEl.textContent = scorer;
    goalBannerEl.classList.add('show');
    goalBanner.showing = true;
    stopPlayback();
}

function hideGoal() {
    goalBannerEl.classList.remove('show');
    goalBanner.showing = false;
}

// ───────────────────────────────────────────
// Playback
// ───────────────────────────────────────────
function getInterval() {
    const spd = parseInt(speedSlider.value);
    return Math.max(80, 1000 / spd);
}

function startPlayback() {
    if (playing) return;
    if (currentIdx >= games.length - 1) {
        currentIdx = 0;
        hideGoal();
    }
    playing = true;
    btnPlay.textContent = '⏸ Pause';
    btnPlay.classList.add('paused');
    function tick() {
        if (!playing) return;
        if (currentIdx < games.length - 1) {
            drawRound(currentIdx + 1);
            animTimer = setTimeout(tick, getInterval());
        } else {
            stopPlayback();
        }
    }
    animTimer = setTimeout(tick, getInterval());
}

function stopPlayback() {
    playing = false;
    clearTimeout(animTimer);
    btnPlay.textContent = '▶ Play';
    btnPlay.classList.remove('paused');
}

// ───────────────────────────────────────────
// Controls
// ───────────────────────────────────────────
btnPlay.addEventListener('click', () => {
    if (playing) stopPlayback(); else startPlayback();
});

btnBack.addEventListener('click', () => {
    stopPlayback();
    hideGoal();
    if (currentIdx > 0) drawRound(currentIdx - 1);
});

btnFwd.addEventListener('click', () => {
    stopPlayback();
    if (currentIdx < games.length - 1) drawRound(currentIdx + 1);
    else checkGoal(games[currentIdx].ball);
});

btnReset.addEventListener('click', () => {
    stopPlayback();
    hideGoal();
    scoreEl.textContent = '0 - 0';
    drawRound(0);
});

timeline.addEventListener('input', () => {
    stopPlayback();
    hideGoal();
    drawTimeFrame(parseInt(timeline.value), selectedTime);
    curRoundEl.innerText = timeline.value
});

speedSlider.addEventListener('input', () => {
    speedVal.textContent = speedSlider.value;
});

dropdown.addEventListener('change', (event) => {
    let select = event.target;
    selectedGame = parseInt(select.value);
    timeline.max = games[selectedGame - 1].times.length;
    timeline.value = 0
    totalRoundsEl.textContent = games[selectedGame - 1].times.length;
    drawTimeFrame(1, selectedGame)
})

// ───────────────────────────────────────────
// Tooltip on hover
// ───────────────────────────────────────────
canvas.addEventListener('mousemove', (e) => {
    if (!games.length) return;
    const rect = canvas.getBoundingClientRect();
    const scaleXr = CANVAS_W / rect.width;
    const scaleYr = CANVAS_H / rect.height;
    const mx = (e.clientX - rect.left) * scaleXr;
    const my = (e.clientY - rect.top) * scaleYr;

    const round = games[currentIdx];
    let found = null;
    for (const p of round.players) {
    const dx = px(p.x) - mx;
    const dy = py(p.y) - my;
    if (Math.sqrt(dx * dx + dy * dy) < 14) { found = p; break; }
    }

    if (found) {
    tooltip.style.display = 'block';
    tooltip.style.left = (e.clientX + 14) + 'px';
    tooltip.style.top = (e.clientY - 10) + 'px';
    const tc = TEAM_COLORS[found.team];
    tooltip.innerHTML =
        `<b style="color:${tc.fill}">${found.name}</b><br>` +
        `${found.team} · ${found.role}<br>` +
        `pos (${found.x}, ${found.y})`;
    } else {
    tooltip.style.display = 'none';
    }
});

canvas.addEventListener('mouseleave', () => { tooltip.style.display = 'none'; });

// ───────────────────────────────────────────
// Drawing
// ───────────────────────────────────────────
function px(x) { return x * scaleX; }
function py(y) { return y * scaleY; }

function drawField() {
    const g = ctx.createLinearGradient(0, 0, 0, CANVAS_H);
    g.addColorStop(0, '#1a4a2e');
    g.addColorStop(0.5, '#1f5a35');
    g.addColorStop(1, '#1a4a2e');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

    // Stripe pattern
    ctx.fillStyle = 'rgba(255,255,255,0.025)';
    for (let i = 0; i < FIELD_W; i += 10) {
    if (Math.floor(i / 10) % 2 === 0) {
        ctx.fillRect(px(i), 0, px(10), CANVAS_H);
    }
    }

    ctx.strokeStyle = 'rgba(255,255,255,0.55)';
    ctx.lineWidth = 2;

    // Boundary
    ctx.strokeRect(px(2), py(2), px(116), py(56));

    // Centre line
    ctx.beginPath(); ctx.moveTo(px(60), py(2)); ctx.lineTo(px(60), py(58)); ctx.stroke();

    // Centre circle
    ctx.beginPath();
    ctx.arc(px(60), py(30), py(10), 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(px(60), py(30), 4, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.fill();

    // Goal areas  (width=6, height=20)
    ctx.strokeRect(px(2), py(20), px(6), py(20));
    ctx.strokeRect(px(112), py(20), px(6), py(20));

    // Goals (net area)
    ctx.strokeStyle = 'rgba(255,255,255,0.75)';
    ctx.lineWidth = 3;
    ctx.strokeRect(px(0), py(27), px(2), py(6));   // left goal
    ctx.strokeRect(px(118), py(27), px(2), py(6)); // right goal
    ctx.lineWidth = 2;
    ctx.strokeStyle = 'rgba(255,255,255,0.55)';

    // Penalty spots
    drawDot(px(8), py(30), 4, '#ffffffaa');
    drawDot(px(112), py(30), 4, '#ffffffaa');
}

function drawDot(x, y, r, color) {
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
}

function drawPlayer(p) {
    const x = px(p.x);
    const y = py(p.y);
    const r = 11;
    const tc = TEAM_COLORS[p.team];
    const shape = ROLE_SHAPE[p.role] || 'circle';

    ctx.save();
    ctx.translate(x, y);

    // Shadow
    ctx.beginPath();
    ctx.ellipse(0, 5, r, 4, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.fill();

    ctx.shadowColor = tc.fill;
    ctx.shadowBlur = 10;

    ctx.fillStyle = tc.fill;
    ctx.strokeStyle = tc.stroke;
    ctx.lineWidth = 2;

    switch (shape) {
    case 'circle':
        ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
        break;
    case 'square':
        ctx.fillRect(-r, -r, r * 2, r * 2);
        ctx.strokeRect(-r, -r, r * 2, r * 2);
        break;
    case 'diamond':
        ctx.beginPath();
        ctx.moveTo(0, -r); ctx.lineTo(r, 0); ctx.lineTo(0, r); ctx.lineTo(-r, 0); ctx.closePath();
        ctx.fill(); ctx.stroke();
        break;
    case 'hexagon':
        ctx.beginPath();
        for (let i = 0; i < 6; i++) {
        const angle = (Math.PI / 3) * i - Math.PI / 6;
        const hx = r * Math.cos(angle), hy = r * Math.sin(angle);
        i === 0 ? ctx.moveTo(hx, hy) : ctx.lineTo(hx, hy);
        }
        ctx.closePath(); ctx.fill(); ctx.stroke();
        break;
    }

    ctx.shadowBlur = 0;

    // Initials
    ctx.fillStyle = tc.stroke;
    ctx.font = `bold ${shape === 'square' ? 8 : 7}px Inter`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    const initial = p.name.charAt(0).toUpperCase();
    ctx.fillText(initial, 0, 0);

    // Name label
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.font = '7px Inter';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText(p.name, 0, r + 3);

    ctx.restore();
}

function drawBall(ball) {
    const x = px(ball.x);
    const y = py(ball.y);

    // Shadow
    ctx.beginPath();
    ctx.ellipse(x, y + 5, 8, 4, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.fill();

    // Glow
    ctx.shadowColor = '#ffe060';
    ctx.shadowBlur = 18;

    // Ball
    ctx.beginPath();
    ctx.arc(x, y, 8, 0, Math.PI * 2);
    const bg = ctx.createRadialGradient(x - 2, y - 2, 1, x, y, 8);
    bg.addColorStop(0, '#fff');
    bg.addColorStop(1, '#ccc');
    ctx.fillStyle = bg;
    ctx.fill();
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // Pentagon patches
    ctx.fillStyle = '#222';
    const patches = [[0, -4], [4, 2], [-4, 2]];
    patches.forEach(([ox, oy]) => {
    ctx.beginPath();
    ctx.arc(x + ox, y + oy, 2, 0, Math.PI * 2);
    ctx.fill();
    });

    ctx.shadowBlur = 0;
}

// function drawRound(idx) {
//     if (!games.length) return;
//     const game = games[idx];
//     const firstTimeframe = game.times[0];
//     console.log(game);
//     console.log(firstTimeframe);
//     currentIdx = idx;

//     ctx.clearRect(0, 0, CANVAS_W, CANVAS_H);
//     drawField();
//     console.log(firstTimeframe.players)
//     firstTimeframe.players.forEach(drawPlayer);
//     drawBall(firstTimeframe.ball);

//     curRoundEl.textContent = 1;
    
//     // need to change this to actual time frame
//     // timeline.value = idx;

//     // Check last round for goal
//     if (idx === games.length - 1) {
//         checkGoal(game.ball);
//     } else {
//         hideGoal();
//     }
// }

function drawTimeFrame(timeIdx, gameIdx) {
    console.log(timeIdx, gameIdx);
    if (!games.length) return;
    const game = games[gameIdx];
    const selectedTimeFrame = game.times[timeIdx - 1];

    ctx.clearRect(0, 0, CANVAS_W, CANVAS_H);
    drawField();
    selectedTimeFrame.players.forEach(drawPlayer);
    drawBall(selectedTimeFrame.ball);

    curRoundEl.textContent = gameIdx;

    // if (gameIdx === games.length - 1) {
    //     checkGoal(game.ball);
    // } else {
    //     hideGoal();
    // }
}

// ───────────────────────────────────────────
// Boot
// ───────────────────────────────────────────
loadLog();