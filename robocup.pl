%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.
:- dynamic log_stream/1.
:- dynamic log_round_count/1.

%----------------------------------------------------------------------
% Set up
%----------------------------------------------------------------------
field(size(120, 60)).

start_one_round:- setup, init_log, simulate_round, finalize_log.

setup:-
    retractall(ball(position(_,_))),
    retractall(player(_,_,_,_,_,_,_)),
    
    assertz(ball(position(60, 30))),

    % work for niner to list the football player
    % player(Name, Team, Role, position(X,Y), Kickpower, Speed, Stamina)
    
    % tchounamenigga
    
    % real madrid galapagos
    % 4-3-3 formation on the left half (field 120x60)
    % Forwards (X=50, spread Y: 15, 30, 45)
    assertz(player(ronaldo,  team1, forward,    position(50, 15), 40, 8,  100)),
    assertz(player(bale,     team1, forward,    position(50, 30), 20, 10, 100)),
    assertz(player(benzema,  team1, forward,    position(50, 45), 10, 2,  100)),
    % Midfielders (X=35, spread Y: 15, 30, 45)
    assertz(player(modric,   team1, midfield,   position(35, 15), 40, 8,  100)),
    assertz(player(casemiro, team1, midfield,   position(35, 30), 20, 10, 100)),
    assertz(player(kroos,    team1, midfield,   position(35, 45), 10, 2,  100)),
    % Defenders (X=15, spread Y: 10, 23, 37, 50)
    assertz(player(carvajal, team1, defender,   position(15, 10), 10, 7,  100)),
    assertz(player(varane,   team1, defender,   position(15, 23), 10, 6,  100)),
    assertz(player(ramos,    team1, defender,   position(15, 37), 10, 6,  100)),
    assertz(player(pepe,     team1, defender,   position(15, 50), 10, 7,  100)),
    % Goalkeeper (X=3, centre Y=30)
    assertz(player(navas,    team1, goalkeeper, position(3,  30), 10, 2,  100)),


    % barcelona 2014 tiki-taka 4-3-3 on the right half (field 120x60)
    % Forwards (X=70, spread Y: 15, 30, 45) — attack toward X=0
    assertz(player(neymar,      team2, forward,    position(70, 15), 35, 9,  100)),
    assertz(player(suarez,       team2, forward,    position(70, 30), 45, 10, 100)),
    assertz(player(messi,       team2, forward,    position(70, 45), 30, 9,  100)),
    % Midfielders (X=85, spread Y: 15, 30, 45)
    assertz(player(iniesta,     team2, midfield,   position(85, 15), 30, 8,  100)),
    assertz(player(busquets,    team2, midfield,   position(85, 30), 20, 7,  100)),
    assertz(player(xavi,        team2, midfield,   position(85, 45), 30, 7,  100)),
    % Defenders (X=105, spread Y: 10, 23, 37, 50)
    assertz(player(alves,       team2, defender,   position(105, 10), 15, 8, 100)),
    assertz(player(pique,       team2, defender,   position(105, 23), 10, 6, 100)),
    assertz(player(mascherano,  team2, defender,   position(105, 37), 10, 6, 100)),
    assertz(player(alba,        team2, defender,   position(105, 50), 15, 8, 100)),
    % Goalkeeper (X=117, centre Y=30)
    assertz(player(bravo,       team2, goalkeeper, position(117, 30), 10, 2, 100)),

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
    writeln('============================'),
    writeln('========Game Started========'),
    writeln('============================').

%goal_position(team1, position()) means team1 is attacking, goal of team2
goal_position(team1, position(120, 30)).
goal_position(team2, position(0, 30)).

%----------------------------------------------------------------------
% JSON Logging
%----------------------------------------------------------------------

init_log :-
    retractall(log_stream(_)),
    retractall(log_round_count(_)),
    assertz(log_round_count(0)),
    open('game_log.json', write, S),
    assertz(log_stream(S)),
    write(S, '{"field":{"width":120,"height":60},"rounds":['),
    flush_output(S).

log_state :-
    log_stream(S),
    log_round_count(N),
    (N > 0 -> write(S, ',') ; true),
    N1 is N + 1,
    retract(log_round_count(_)),
    assertz(log_round_count(N1)),
    ball(position(BX, BY)),
    format(S, '{"round":~w,"ball":{"x":~w,"y":~w},"players":[', [N1, BX, BY]),
    findall(p(Name,Team,Role,X,Y),
        player(Name,Team,Role,position(X,Y),_,_,_),
        Players),
    write_players_json(S, Players, true),
    write(S, ']}'),
    flush_output(S).

write_players_json(_, [], _) :- !.
write_players_json(S, [p(Name,Team,Role,X,Y)|Rest], First) :-
    (First = true -> true ; write(S, ',')),
    format(S, '{"name":"~w","team":"~w","role":"~w","x":~w,"y":~w}',
           [Name, Team, Role, X, Y]),
    write_players_json(S, Rest, false).

finalize_log :-
    log_stream(S),
    write(S, ']}'),
    nl(S),
    close(S),
    retract(log_stream(S)),
    writeln('game_log.json written.').    

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
    XDist =< Speed,
    YDist =< Speed,

    % Kick toward opponent goal
    goal_position(Team, position(GoalX, GoalY)),
    XDiff is GoalX - BX,
    YDiff is GoalY - BY,

    % Calculate the final position of the ball based on the kicking power
    calculate_x_y_distance(Kickpower, XDiff, YDiff, XDis, YDis),
    NewBX is BX + XDis,
    NewBY is BY + YDis,
    
    format(
        '~n The ball is kicked from (~w, ~w) to (~w, ~w) by ~w ~n', 
        [BX, BY, NewBX, NewBY, Name]
    ),
    retract(ball(position(BX, BY))),
    assertz(ball(position(NewBX, NewBY))).

%----------------------------------------------------------------------
% Check goal
%----------------------------------------------------------------------

check_goal :-
    ball(position(BX, BY)),
    ((BX >= 120, BY >= 27, BY =< 33) ->
        write('***Goal for team1***');
    (BX =< 0, BY >= 27, BY =< 33) ->
        write('***Goal for team2***')
    ;
        false
    ).

%----------------------------------------------------------------------
% Simulate single round
%----------------------------------------------------------------------

simulate_round :-
    log_state,
    ball(position(BX,BY)),
    format('~n Ball is now at (~w, ~w) | ', [BX, BY]),
    forall(
        player(Name, _, _, _, _, _, _),
        (
            move_towards_ball(Name),
            ( kick_ball(Name) -> true ; true )
        )
    ),
    ( check_goal ->
        true;
        simulate_round
    ).

%----------------------------------------------------------------------
% Simulate multiple round (need random to make this work, otw it will be the same every round)
%----------------------------------------------------------------------

round_simulation(RoundCount):-
    RoundCount > 0,
    NewRoundCount is RoundCount - 1,
    simulate_round,
    run_simulation(NewRoundCount).
