%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.
:- dynamic score/2.
:- dynamic game_log/1.
:- dynamic current_game/2.
:- dynamic current_time/2.
:- dynamic ball_kicked/0.
:- dynamic last_kick/1.

%----------------------------------------------------------------------
% Set up
%----------------------------------------------------------------------
field(size(120, 60)).

% restart all the predicate, including player and ball position, and scoring.
setup:-
    restart_new_round,
    retractall(score(_,_)),

    assertz(score(0,0)),

    ball(position(BX, BY)),
    format('The ball starts at position (~w, ~w)~n', [BX, BY]),

    writeln('Players from team1:'),
    forall(
        player(Name, team1, Role, _, _, _, _),
        format('  -- ~w -- plays as ~w~n', [Name, Role])
    ),

    writeln('Players from team2:'),
    forall(
        player(Name, team2, Role, _, _, _, _),
        format('  -- ~w -- plays as ~w~n', [Name, Role])
    ),
    writeln(''),
    writeln('============================'),
    writeln('========Game Started========'),
    writeln('============================').

%restart only the player and ball position, not the score
restart_new_round :-
    retractall(ball(position(_,_))),
    retractall(player(_,_,_,_,_,_,_)),

    assertz(ball(position(60, 30))),

    % player(Name, Team, Role, position(X,Y), Kickpower, Speed, Stamina)
    
    % team1 — Real Madrid, 2-3-1 on left side
    assertz(player(ronaldo,    team1, forward,    position(50, 30), 40, 3, 100)),
    assertz(player(modric,     team1, midfield,   position(35, 15), 32, 2,  100)),
    assertz(player(casemiro,   team1, midfield,   position(35, 30), 35, 2, 100)),
    assertz(player(kroos,      team1, midfield,   position(35, 45), 33, 2,  100)),
    assertz(player(varane,     team1, defender,   position(15, 23), 40, 1.5,  100)),
    assertz(player(ramos,      team1, defender,   position(15, 37), 40, 1.5,  100)),
    assertz(player(navas,      team1, goalkeeper, position(1,  30), 67, 1.5,  100)),

    % team2 — Barcelona, 2-3-1 on right side
    assertz(player(messi,     team2, forward,    position(70, 30), 30, 2.5, 100)),
    assertz(player(iniesta,    team2, midfield,   position(85, 15), 32, 2,  100)),
    assertz(player(busquets,   team2, midfield,   position(85, 30), 35, 2,  100)),
    assertz(player(xavi,       team2, midfield,   position(85, 45), 42, 2,  100)),
    assertz(player(pique,      team2, defender,   position(105, 23), 46, 1.5, 100)),
    assertz(player(mascherano, team2, defender,   position(105, 37), 48, 1.5, 100)),
    assertz(player(bravo,      team2, goalkeeper, position(119, 30), 65, 1.5, 100)).

%goal_position(team1, position()) means team1 is attacking, goal of team2
goal_position(team1, position(120, 30)).
goal_position(team2, position(0, 30)).

%----------------------------------------------------------------------
% Useful function
%----------------------------------------------------------------------

sign(X, 1):- X > 0.
sign(X, -1):- X < 0.
sign(X, 0):- X =:= 0.

calculate_x_y_distance(_, 0, 0, 0, 0):- !.

calculate_x_y_distance(Power, XDiff, YDiff, XDis, YDis):-
    Distance is round(sqrt((XDiff^2) + (YDiff^2))),
    XDis is ceil(Power * XDiff / Distance),
    YDis is ceil(Power * YDiff / Distance).

%for kicking angle inaccuracy, source: https://matthew-brett.github.io/teaching/rotation_2d.html
rotate_vector(DX, DY, Angle, NewDX, NewDY):-
    NewDX is cos(Angle) * DX - sin(Angle) * DY,
    NewDY is sin(Angle) * DX + cos(Angle) * DY.

%----------------------------------------------------------------------
% Player moving toward ball
%----------------------------------------------------------------------

move_towards_ball(Name):-
    player(Name,Team,Role,position(X1,Y1),Kickpower,Speed,Stamina),
    ball(position(BX,BY)),
    XDiff is BX - X1,
    YDiff is BY - Y1,
    calculate_x_y_distance(Speed, XDiff, YDiff, XDis, YDis),
    NewX is X1 + XDis,
    NewY is Y1 + YDis,
    retract(player(Name, Team, Role, position(X1,Y1), Kickpower, Speed, Stamina)),
    assertz(player(Name, Team, Role, position(NewX,NewY), Kickpower, Speed, Stamina)),
    format(' ~w to (~w, ~w) |', [Name, NewX, NewY]).

%----------------------------------------------------------------------
% Running boundary — enforce zone constraints per role
%----------------------------------------------------------------------

running_boundary(Name) :-
    field(size(FieldW, FieldH)),
    HalfW   is FieldW // 2,
    MidLow  is FieldW // 4,
    MidHigh is (3 * FieldW) // 4,
    player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina),
    ball(position(BX, _)),

    % CASE 1: clamp to field boundaries (always enforced)
    ( X < 0      -> NewX is 0      ; X > FieldW -> NewX is FieldW ; NewX is X ),
    ( Y < 0      -> NewY is 0      ; Y > FieldH -> NewY is FieldH ; NewY is Y ),

    % CASE 2: defenders stay in own half — only if ball is NOT in restricted area
    ( (Role = defender, Team = team1, NewX > HalfW, BX =< HalfW) -> FinalX is HalfW ;
      (Role = defender, Team = team2, NewX < HalfW, BX >= HalfW) -> FinalX is HalfW ;
      FinalX is NewX ),

    % CASE 3: forwards stay in attacking half — only if ball is NOT in their zone
    ( (Role = forward, Team = team1, FinalX < HalfW, BX < HalfW) -> FinalX2 is HalfW ;
      (Role = forward, Team = team2, FinalX > HalfW, BX > HalfW) -> FinalX2 is HalfW ;
      FinalX2 is FinalX ),

    % CASE 4: midfielders stay in middle band — only if ball is NOT in restricted area
    ( (Role = midfield, FinalX2 > MidHigh, BX =< MidHigh) -> FinalX3 is MidHigh ;
      (Role = midfield, FinalX2 < MidLow,  BX >= MidLow)  -> FinalX3 is MidLow  ;
      FinalX3 is FinalX2 ),

    % CASE 5: goalkeeper stays near own goal — only if ball is NOT in their area
    ( (Role = goalkeeper, Team = team1, FinalX3 > 10,  BX > 10)  -> FinalX4 is 10  ;
      (Role = goalkeeper, Team = team2, FinalX3 < 110, BX < 110) -> FinalX4 is 110 ;
      FinalX4 is FinalX3 ),

    % Only update if position actually changed
    ( (FinalX4 =\= X ; NewY =\= Y) ->
        retract(player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina)),
        assertz(player(Name, Team, Role, position(FinalX4, NewY), Kickpower, Speed, Stamina))
    ; true ).

%----------------------------------------------------------------------
% Pass Target Logic
%----------------------------------------------------------------------

get_pass_target(Team, Role, TX, TY) :-
    player(_, Team, Role, position(TX, TY), _, _, _),
    !. % Pick the first available player with the specified role

%----------------------------------------------------------------------
% Player attempt to kicking the ball
%----------------------------------------------------------------------

kick_ball(Name):-
    player(Name,Team,Role,position(X1,Y1),Kickpower,Speed,_),
    ball(position(BX,BY)),

    % Check if player is close enough to kick the ball (within the speed range)
    XDist is abs(BX - X1),
    YDist is abs(BY - Y1),
    XDist =< sqrt(Speed),
    YDist =< sqrt(Speed),

    % Determine target based on Role
    ( Role == defender ->
        ( get_pass_target(Team, midfield, TX, TY) -> 
            TargetX = TX, TargetY = TY, PowerMult = 0.9 
        ; 
            goal_position(Team, position(TargetX, TargetY)), PowerMult = 1.0 
        ),
        ActionStr = 'passes to midfield'
    ; Role == midfield ->
        ( get_pass_target(Team, forward, TX, TY) -> 
            TargetX = TX, TargetY = TY, PowerMult = 0.9 
        ; 
            goal_position(Team, position(TargetX, TargetY)), PowerMult = 1.0 
        ),
        ActionStr = 'passes to forward'
    ; Role == forward ->
        goal_position(Team, position(GoalX, GoalY)),
        DistToGoal is sqrt((GoalX - BX)**2 + (GoalY - BY)**2),
        ( DistToGoal < 40 ->
            TargetX = GoalX, TargetY = GoalY, PowerMult = 1.3, % Shoot
            ActionStr = 'shoots at goal'
        ;
            TargetX = GoalX, TargetY = GoalY, PowerMult = 0.2, % Dribble towards goal
            ActionStr = 'dribbles the ball'
        )
    ; % Goalkeeper
        goal_position(Team, position(TargetX, TargetY)), PowerMult = 1.0,
        ActionStr = 'clears the ball'
    ),

    XDiff is TargetX - BX,
    YDiff is TargetY - BY,

    % Random kicking power (adjusted by role multiplier)
    random(R1), % 0.0 - 1.0
    KickpowerFactor is (4 * ((R1 - 0.5)**3) + 1) * PowerMult,
    ActualKickpower is Kickpower * KickpowerFactor,
    
    % Random kicking angle (reduce angle error for dribbling/passing to make it look intentional)
    random(R2),
    ( Role == forward, PowerMult < 1.0 -> 
        Angle is 0.5 * ((R2 - 0.5)**3) % tighter angle for dribble
    ;
        Angle is 2 * ((R2 - 0.5)**3)
    ),

    % Calculate the final position of the ball based on the kicking power
    calculate_x_y_distance(ActualKickpower, XDiff, YDiff, XDis, YDis),

    % Rotate the vector
    rotate_vector(XDis, YDis, Angle, RandomizedXDis, RandomizedYDis),

    NewBX is BX + round(RandomizedXDis),
    NewBY is BY + round(RandomizedYDis),
    format(
        '~nThe ball is kicked from (~w, ~w) to (~w, ~w) by ~w (~w)~n',
        [BX, BY, NewBX, NewBY, Name, ActionStr]
    ),
    format(
        'with kickpower factor of ~2f and angle of ~4f rad ~n',
        [KickpowerFactor, Angle]
    ),
    retract(ball(position(BX, BY))),
    assertz(ball(position(NewBX, NewBY))),
    retractall(last_kick(_)),
    assertz(last_kick(Name)).

%----------------------------------------------------------------------
% Ball out of field
%----------------------------------------------------------------------

%Change from 0->2 and 120->116 to match the canvas size in html (padding 2 pixel)
ball_out_of_field(team2) :-
    ball(position(BX, _)),
    BX > 116, !.

ball_out_of_field(team1) :-
    ball(position(BX, _)),
    BX < 2, !.

ball_out_of_field(Team) :-
    ball(position(BX, BY)),
    (BY < 2 ; BY > 56),
    ( BX >= 60 -> Team = team2 ; Team = team1 ), !.

%----------------------------------------------------------------------
% Goal Kick
%----------------------------------------------------------------------

goal_kick_back(Team) :-
    format('~n*** Ball out! ~w goal kicks ***~n', [Team]),

    %Decide kick position
    goal_position(Team, position(GoalX, _)),
    ball(position(_, BY)),
    field(size(_, MaxY)),
    KickY is min(max(BY, 0), MaxY),
    retractall(ball(position(_, _))),
    assertz(ball(position(GoalX, KickY))),

    %Kick toward center
    CenterX is 60,
    CenterY is 30,
    XDiff is CenterX - GoalX,
    YDiff is CenterY - KickY,
    random(R1),
    KickpowerFactor is (4 * ((R1 - 0.5)**3) + 1),
    ActualGoalKickpower is 80 * KickpowerFactor,
    calculate_x_y_distance(ActualGoalKickpower, XDiff, YDiff, XDis, YDis),
    NewBX is GoalX + XDis,
    NewBY is KickY + YDis,
    format('Goalkeeper (~w) kicks from (~w,~w) to (~w,~w)~n', [Team, GoalX, KickY, NewBX, NewBY]),
    retractall(ball(position(_, _))),
    assertz(ball(position(NewBX, NewBY))).

%----------------------------------------------------------------------
% Check goal
%----------------------------------------------------------------------

check_goal :-
    check_goal(_).

check_goal(Team) :-
    ball(position(BX, BY)),
    ((BX >= 120, BY >= 27, BY =< 33) ->
        writeln('============================'),
        write('***Goal for team1***'),
        score(Team1,Team2),
        NewTeam1 is Team1 + 1,
        retract(score(Team1, Team2)),
        assertz(score(NewTeam1, Team2)),
        format('~nThe current score [team1 : team2] is [~w : ~w] ~n', [NewTeam1, Team2]),
        writeln('============================'),
        Team = team1
        ;
    (BX =< 0, BY >= 27, BY =< 33) ->
        writeln('============================'),
        write('***Goal for team2***'),
        score(Team1,Team2),
        NewTeam2 is Team2 + 1,
        retract(score(Team1, Team2)),
        assertz(score(Team1, NewTeam2)),
        format('~nThe current score [team1 : team2] is [~w : ~w] ~n', [Team1, NewTeam2]),
        writeln('============================'),
        Team = team2
        ;
        false
    ).

%----------------------------------------------------------------------
% Simulate single round
%----------------------------------------------------------------------

simulate_round :-
    simulate_round(_, 300).
simulate_round(_, 0) :- !,
    writeln('No goal scored this round (tick limit reached)').
simulate_round(GameNum, Ticks) :-
    Ticks > 0,
    ball(position(BX,BY)),
    format('~nBall is now at (~w, ~w) | ', [BX, BY]),

    % Every players move first, then enforce boundary
    forall(
        player(Name,_,_,_,_,_,_),
        ( move_towards_ball(Name), running_boundary(Name) )
    ),
    % Only first eligible player kicks per tick
    retractall(ball_kicked),
    retractall(last_kick(_)),
    forall(
        player(Name,_,_,_,_,_,_),
        ( (\+ ball_kicked, kick_ball(Name)) -> assertz(ball_kicked) ; true )
    ),

    ( last_kick(Kicker) ->
        atomic_list_concat(['kick:', Kicker], ActionKick)
    ; ActionKick = ''
    ),

    ( goalkeeper_save(GKName, GKProb, GKDist) ->
        format('~nGoalkeeper ~w saved the ball (p=~2f, d=~2f)~n', [GKName, GKProb, GKDist]),
        atomic_list_concat(['save:', GKName], ActionSave)
    ; ActionSave = ''
    ),

    ( check_goal(GoalTeam) ->
        atomic_list_concat(['goal:', GoalTeam], ActionGoal),
        build_action([ActionKick, ActionSave, ActionGoal], Action),
        log_time_frame(GameNum, Ticks, Action),
        true   % round ends here, return to round_simulation
    ; ball_out_of_field(Team) ->
        atomic_list_concat(['ball_out:', Team], ActionOut),
        build_action([ActionKick, ActionSave, ActionOut], Action),
        log_time_frame(GameNum, Ticks, Action),
        goal_kick_back(Team),
        NextTick is Ticks - 1,
        simulate_round(GameNum, NextTick)
    ;
        build_action([ActionKick, ActionSave], Action),
        log_time_frame(GameNum, Ticks, Action),
        NextTick is Ticks - 1,
        simulate_round(GameNum, NextTick)
    ).

%----------------------------------------------------------------------
% Simulate multiple round
%----------------------------------------------------------------------

round_simulation(RoundCount):-
    source_file(round_simulation(_), ThisFile),
    file_directory_name(ThisFile, Directory),
    working_directory(_, Directory),
    init_log,
    setup,
    round_simulation(RoundCount, RoundCount).

round_simulation(0, _) :- !,
    score(S1, S2),
    export_json('game_log.json'),
    writeln('============================'),
    writeln('======= FINAL SCORE ========'),
    format('     team1 ~w - ~w team2~n', [S1, S2]),
    writeln('============================').

round_simulation(RoundCount, TotalRoundCount):-
    RoundCount > 0,
    CurrentRound is TotalRoundCount - RoundCount + 1,
    writeln('============================'),
    format('      Round ~w: start!~n', [CurrentRound]),
    writeln('============================'),
    begin_game(CurrentRound),
    simulate_round(CurrentRound, 200),
    end_game(CurrentRound),
    NewRoundCount is RoundCount - 1,
    restart_new_round,   % reset players and ball between rounds
    round_simulation(NewRoundCount, TotalRoundCount).

%----------------------------------------------------------------------
% Logging function
%----------------------------------------------------------------------

init_log :-
    retractall(game_log(_)),
    assertz(game_log([])).

begin_game(GameNum) :-
    retractall(current_game(_,_)),
    assertz(current_game(GameNum, [])).

log_time_frame(GameNum, TimeNum, Action) :-
    ball(position(BX, BY)),
    % Collect all player snapshots inside that time frame
    findall(
        player_snap(Name, Team, Role, PX, PY),
        player(Name, Team, Role, position(PX, PY), _, _, _),
        PlayerSnaps
    ),
    TimeFrame = time_frame(TimeNum, ball(BX, BY), PlayerSnaps, Action),
    retract(current_game(GameNum, Times)),
    append(Times, [TimeFrame], NewTimes),
    assertz(current_game(GameNum, NewTimes)).

end_game(GameNum) :-
    current_game(GameNum, Times),
    score(S1, S2),
    GameEntry = game_entry(GameNum, S1, S2, Times),
    retract(game_log(Games)),
    append(Games, [GameEntry], NewGames),
    assertz(game_log(NewGames)).

count_goals(Times, Team1, Team2) :-
    count_goals(Times, 0, 0, Team1, Team2).

count_goals([], T1, T2, T1, T2).
count_goals([time_entry(_, goal, team1) | Rest], T1, T2, R1, R2) :-
    T1Next is T1 + 1,
    count_goals(Rest, T1Next, T2, R1, R2).
count_goals([time_entry(_, goal, team2) | Rest], T1, T2, R1, R2) :-
    T2Next is T2 + 1,
    count_goals(Rest, T1, T2Next, R1, R2).
count_goals([_ | Rest], T1, T2, R1, R2) :-
    count_goals(Rest, T1, T2, R1, R2).

%----------------------------------------------------------------------
% Goalkeeper Movement
%----------------------------------------------------------------------

goalkeeper_save_radius(8).
goalkeeper_save_sigma(4).

goalkeeper_save(Name, Probability, Dist) :-
    ball(position(BX, BY)),
    goalkeeper_save_radius(Radius),
    goalkeeper_save_sigma(Sigma),
    player(Name, _, goalkeeper, position(KX, KY), _, _, _),
    DX is BX - KX,
    DY is BY - KY,
    Dist is sqrt(DX * DX + DY * DY),
    Dist =< Radius,
    Probability is exp(- (Dist * Dist) / (2 * Sigma * Sigma)),
    random(Rnd),
    Rnd < Probability,
    retractall(ball(position(_, _))),
    assertz(ball(position(KX, KY))),
    !.

build_action(Parts, Action) :-
    filter_action_parts(Parts, Clean),
    ( Clean = [] ->
        Action = ''
    ;
        atomic_list_concat(Clean, ';', Action)
    ).

filter_action_parts([], []).
filter_action_parts(['' | Tail], Clean) :-
    filter_action_parts(Tail, Clean).
filter_action_parts([H | Tail], [H | CleanTail]) :-
    H \= '',
    filter_action_parts(Tail, CleanTail).

%----------------------------------------------------------------------
% Logging function
%----------------------------------------------------------------------

%This part is trying to imitate JSON format and write to variable Stream with prolog write 

export_json(FileName):-
    game_log(Games),
    open(FileName, write, Stream),

    write(Stream, '{'),
    nl(Stream),

    %Field 
    write(Stream, '  "field": {'),   nl(Stream),
    write(Stream, '    "width": 120,'),  nl(Stream),
    write(Stream, '    "height": 60'),   nl(Stream),
    write(Stream, '  },'),  nl(Stream),

    %Games array
    write(Stream, '  "games": ['), nl(Stream),
    length(Games, GLen),
    write_games(Stream, Games, GLen, 1),
    write(Stream, '  ]'),  nl(Stream),
    write(Stream, '}'),    nl(Stream),
    close(Stream),
    format('~nGame log exported to ~w~n', [FileName]).

write_games(_, [], _, _).
write_games(Stream, [game_entry(GameNum, S1, S2, Times) | Tail], TotalGames, Idx):-
    write(Stream, '    {'),  nl(Stream),
    format(Stream, '      "game": ~w,~n', [GameNum]),
    format(Stream, '      "score": {~n        "team1": ~w,~n        "team2": ~w~n      },~n', [S1, S2]),
    write(Stream,  '      "times": ['), nl(Stream),
    length(Times, TLen),
    write_times(Stream, Times, TLen, 1),
    write(Stream, '      ]'),  nl(Stream),
    ( Idx < TotalGames ->
        write(Stream, '    },'), nl(Stream)
    ;
        write(Stream, '    }'),  nl(Stream)
    ),
    NextIdx is Idx + 1,
    write_games(Stream, Tail, TotalGames, NextIdx).

write_times(_, [], _, _).
write_times(Stream, [time_frame(TimeNum, ball(BX, BY), Players, Action)| Tail], TotalTimes, Idx) :-
    write(Stream, '        {'), nl(Stream),
    format(Stream, '          "time": ~w,~n', [TimeNum]),
    write(Stream,  '          "ball": {'), nl(Stream),
    format(Stream, '            "x": ~w,~n', [BX]),
    format(Stream, '            "y": ~w~n',  [BY]),
    write(Stream,  '          },'), nl(Stream),
    format(Stream, '          "action": "~w",~n', [Action]),
    write(Stream,  '          "players": ['), nl(Stream),
    length(Players, PLen),
    write_players(Stream, Players, PLen, 1),
    write(Stream, '          ]'), nl(Stream),
    ( Idx < TotalTimes ->
        write(Stream, '        },'), nl(Stream)
    ;
        write(Stream, '        }'),  nl(Stream)
    ),
    NextIdx is Idx + 1,
    write_times(Stream, Tail, TotalTimes, NextIdx).

write_players(_, [], _, _).
write_players(Stream, [player_snap(Name, Team, Role, PX, PY) | Tail], TotalPlayers, Idx) :-
    write(Stream, '            {'), nl(Stream),
    format(Stream, '              "name": "~w",~n', [Name]),
    format(Stream, '              "team": "~w",~n', [Team]),
    format(Stream, '              "role": "~w",~n', [Role]),
    format(Stream, '              "x": ~w,~n',      [PX]),
    format(Stream, '              "y": ~w~n',        [PY]),
    ( Idx < TotalPlayers ->
        write(Stream, '            },'), nl(Stream)
    ;
        write(Stream, '            }'),  nl(Stream)
    ),
    NextIdx is Idx + 1,
    write_players(Stream, Tail, TotalPlayers, NextIdx).