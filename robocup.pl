%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.
:- dynamic score/2.
:- dynamic game_log/1.
:- dynamic current_game/2.
:- dynamic current_time/2.

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
    
    assertz(ball(position(60, 4))),

    % work for niner to list the football player
    % player(Name,Team,Role,position(X1,Y1),Kickpower,Speed,Stamina)
    assertz(player(niner, team1, forward, position(10,27), 40, 2, 100)),
    assertz(player(peace, team1, forward, position(40,13), 20, 2, 100)),
    assertz(player(p, team2, forward, position(82,15), 30, 2, 100)),
    assertz(player(guy, team2, defender, position(112,22), 60, 2, 100)).

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
% Player attempt to kicking the ball
%----------------------------------------------------------------------

kick_ball(Name):-
    player(Name,Team,_,position(X1,Y1),Kickpower,Speed,_),
    ball(position(BX,BY)),

    % Check if player is close enough to kick the ball (within the speed range)
    XDist is abs(BX - X1),
    YDist is abs(BY - Y1),
    XDist =< sqrt(Speed),
    YDist =< sqrt(Speed),

    % Kick toward opponent goal
    goal_position(Team, position(GoalX, GoalY)),
    XDiff is GoalX - BX,
    YDiff is GoalY - BY,

    % Random kicking power
    random(R1), % 0.0 - 1.0
    KickpowerFactor is (4 * ((R1 - 0.5)**3) + 1), % [0.5, 1.5]
    ActualKickpower is Kickpower * KickpowerFactor,
    
    % Random kicking angle
    random(R2),
    Angle is 4 * ((R2 - 0.5)**3), % [-0.5, 0.5] rad

    % Calculate the final position of the ball based on the kicking power
    calculate_x_y_distance(ActualKickpower, XDiff, YDiff, XDis, YDis),

    % Rotate the vector
    rotate_vector(XDis, YDis, Angle, RandomizedXDis, RandomizedYDis),

    NewBX is BX + round(RandomizedXDis),
    NewBY is BY + round(RandomizedYDis),
    format(
        '~nThe ball is kicked from (~w, ~w) to (~w, ~w) by ~w ~n', 
        [BX, BY, NewBX, NewBY, Name]
    ),
    format(
        'with kickpower factor of ~2f and angle of ~4f rad ~n',
        [KickpowerFactor, Angle]
    ),
    retract(ball(position(BX, BY))),
    assertz(ball(position(NewBX, NewBY))).

%----------------------------------------------------------------------
% Check goal
%----------------------------------------------------------------------

check_goal :-
    ball(position(BX, BY)),
    ((BX >= 120, BY >= 27, BY =< 33) ->
        writeln('============================'),
        write('***Goal for team1***'),
        score(Team1,Team2),
        NewTeam1 is Team1 + 1,
        retract(score(Team1, Team2)),
        assertz(score(NewTeam1, Team2)),
        format('~nThe current score [team1 : team2] is [~w : ~w] ~n', [NewTeam1, Team2]),
        writeln('============================')
        ;
    (BX =< 0, BY >= 27, BY =< 33) ->
        writeln('============================'),
        write('***Goal for team2***'),
        score(Team1,Team2),
        NewTeam2 is Team2 + 1,
        retract(score(Team1, Team2)),
        assertz(score(Team1, NewTeam2)),
        format('~nThe current score [team1 : team2] is [~w : ~w] ~n', [Team1, NewTeam2]),
        writeln('============================')
        ;
        false
    ).

%----------------------------------------------------------------------
% Simulate single round
%----------------------------------------------------------------------

simulate_round(GameNum, TimeNum) :-
    ball(position(BX,BY)),
    format('~nBall is now at (~w, ~w) | ', [BX, BY]),
    
    % Every players move first
    forall(
        player(Name,_,_,_,_,_,_),
        move_towards_ball(Name)
    ),
    % Then kick
    forall(
        player(Name,_,_,_,_,_,_),
        ( kick_ball(Name) -> true ; true)
    ),

    log_time_frame(GameNum, TimeNum),

    ( check_goal ->
        end_game(GameNum), restart_new_round;
        NextTime is TimeNum + 1,
        simulate_round(GameNum, NextTime)
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

round_simulation(0, _):-
    export_json('game_log.json'),
    !.

round_simulation(RoundCount, TotalRoundCount):-
    RoundCount > 0,
    CurrentRound is TotalRoundCount - RoundCount + 1,
    writeln('============================'),
    format('      Round ~w: start!~n', [CurrentRound]),
    writeln('============================'),
    begin_game(CurrentRound),
    simulate_round(CurrentRound, 1),
    NewRoundCount is RoundCount - 1,
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

log_time_frame(GameNum, TimeNum) :-
    ball(position(BX, BY)),
    % Collect all player snapshots inside that time frame
    findall(
        player_snap(Name, Team, Role, PX, PY),
        player(Name, Team, Role, position(PX, PY), _, _, _),
        PlayerSnaps
    ),
    TimeFrame = time_frame(TimeNum, ball(BX, BY), PlayerSnaps),
    retract(current_game(GameNum, Times)),
    append(Times, [TimeFrame], NewTimes),
    assertz(current_game(GameNum, NewTimes)).

end_game(GameNum) :-
    current_game(GameNum, Times),
    GameEntry = game_entry(GameNum, Times),
    retract(game_log(Games)),
    append(Games, [GameEntry], NewGames),
    assertz(game_log(NewGames)).

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
write_games(Stream, [game_entry(GameNum, Times) | Tail], TotalGames, Idx):-
    write(Stream, '    {'),  nl(Stream),
    format(Stream, '      "game": ~w,~n', [GameNum]),
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
write_times(Stream, [time_frame(TimeNum, ball(BX, BY), Players)| Tail], TotalTimes, Idx) :-
    write(Stream, '        {'), nl(Stream),
    format(Stream, '          "time": ~w,~n', [TimeNum]),
    write(Stream,  '          "ball": {'), nl(Stream),
    format(Stream, '            "x": ~w,~n', [BX]),
    format(Stream, '            "y": ~w~n',  [BY]),
    write(Stream,  '          },'), nl(Stream),
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

