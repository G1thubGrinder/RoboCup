%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.

%----------------------------------------------------------------------
% Set up
%----------------------------------------------------------------------
field(size(120, 60)).

start_one_round:- setup, simulate_round.

setup:-
    retractall(ball(position(_,_))),
    retractall(player(_,_,_,_,_,_,_)),
    
    assertz(ball(position(60, 0))),

    % work for niner to list the football player
    assertz(player(niner, team1, forward, position(0,0), 40, 8, 100)),
    assertz(player(peace, team1, forward, position(0,60), 20, 10, 100)),
    assertz(player(p, team2, forward, position(61,0), 30, 5, 100)),
    assertz(player(guy, team2, defender, position(110,30), 80, 3, 100)),

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

    % Check if player is close enough to kick the ball (within 1 adjacent square)
    XDist is abs(BX - X1),
    YDist is abs(BY - Y1),
    XDist =< Speed,
    YDist =< Speed,

    % Kick toward opponent goal
    goal_position(Team, position(GoalX, GoalY)),
    XDiff is GoalX - BX,
    YDiff is GoalY - BY,
    %sign(XDiff, SX),
    %sign(YDiff, SY),

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
