%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.

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
    
    assertz(ball(position(60, 0))),

    % work for niner to list the football player
    % player(Name,Team,Role,position(X1,Y1),Kickpower,Speed,Stamina)
    assertz(player(niner, team1, forward, position(10,27), 40, 6, 100)),
    assertz(player(peace, team1, forward, position(40,13), 20, 8, 100)),
    assertz(player(p, team2, forward, position(82,15), 30, 5, 100)),
    assertz(player(guy, team2, defender, position(112,22), 60, 4, 100)).

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

simulate_round :-
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
    ( check_goal ->
        true, restart_new_round;
        simulate_round
    ).

%----------------------------------------------------------------------
% Simulate multiple round
%----------------------------------------------------------------------

round_simulation(RoundCount):-
    setup,
    round_simulation(RoundCount, RoundCount).

round_simulation(RoundCount, TotalRoundCount):-
    RoundCount > 0,
    CurrentRound is TotalRoundCount - RoundCount + 1,
    writeln('============================'),
    format('      Round ~w: start!~n', [CurrentRound]),
    writeln('============================'),
    NewRoundCount is RoundCount - 1,
    simulate_round,
    round_simulation(NewRoundCount, TotalRoundCount).