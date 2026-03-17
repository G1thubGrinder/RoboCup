%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.

field(size(120, 60)).

ball(position(60, 30)).

%niner (name, team, role, position(), kickpower, speed, stamina)
player( a, team1, forward, position(50,30), 2, 3, 50).

sign(X, 1):- X > 0.
sign(X, -1):- X < 0.
sign(X, 0):- X =:= 0.

move_towards_ball(Name):-
    player(Name,Team,Role,position(X1,Y1),Kickpower,Speed,Stamina),
    ball(position(X2,Y2)),
    XDiff is X2 - X1,
    YDiff is Y2 - Y1,
    sign(XDiff, DX),
    sign(YDiff, DY),
    NewX is X1 + DX,
    NewY is Y1 + DY,
    retract(player(Name, Team, Role, position(X1,Y1), Kickpower, Speed, Stamina)),
    assertz(player(Name, Team, Role, position(NewX,NewY), Kickpower, Speed, Stamina)),
    format('~w moves to (~w, ~w)~n', [Name, NewX, NewY]).

simulate_round :-
    move_towards_ball(a).

run_simulation(RoundCount):-
    RoundCount > 0,
    NewRoundCount is RoundCount - 1,
    simulate_round,
    run_simulation(NewRoundCount).