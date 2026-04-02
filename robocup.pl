%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.
:- dynamic score/2.

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
    assertz(player(ronaldo,    team1, forward,    position(50, 30), 20, 10, 100)),
    assertz(player(modric,     team1, midfield,   position(35, 15), 40, 8,  100)),
    assertz(player(casemiro,   team1, midfield,   position(35, 30), 20, 10, 100)),
    assertz(player(kroos,      team1, midfield,   position(35, 45), 10, 2,  100)),
    assertz(player(varane,     team1, defender,   position(15, 23), 10, 6,  100)),
    assertz(player(ramos,      team1, defender,   position(15, 37), 10, 6,  100)),
    assertz(player(navas,      team1, goalkeeper, position(1,  30), 10, 2,  100)),

    % team2 — Barcelona, 2-3-1 on right side
    assertz(player(suarez,     team2, forward,    position(70, 30), 45, 10, 100)),
    assertz(player(iniesta,    team2, midfield,   position(85, 15), 30, 8,  100)),
    assertz(player(busquets,   team2, midfield,   position(85, 30), 20, 7,  100)),
    assertz(player(xavi,       team2, midfield,   position(85, 45), 30, 7,  100)),
    assertz(player(pique,      team2, defender,   position(105, 23), 10, 6, 100)),
    assertz(player(mascherano, team2, defender,   position(105, 37), 10, 6, 100)),
    assertz(player(bravo,      team2, goalkeeper, position(119, 30), 10, 2, 100)).

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
    HalfW is FieldW // 2,
    player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina),

    % CASE 1: clamp to field boundaries
    ( X < 0      -> NewX is 0      ; X > FieldW -> NewX is FieldW ; NewX is X ),
    ( Y < 0      -> NewY is 0      ; Y > FieldH -> NewY is FieldH ; NewY is Y ),

    MidLow  is FieldW // 4,
    MidHigh is (3 * FieldW) // 4,

    % CASE 2: defenders stay in own half
    ( (Role = defender, Team = team1, NewX > HalfW) -> FinalX is HalfW ;
      (Role = defender, Team = team2, NewX < HalfW) -> FinalX is HalfW ;
      FinalX is NewX ),

    % CASE 3: forwards stay in attacking half
    ( (Role = forward, Team = team1, FinalX < HalfW) -> FinalX2 is HalfW ;
      (Role = forward, Team = team2, FinalX > HalfW) -> FinalX2 is HalfW ;
      FinalX2 is FinalX ),

    % CASE 4: midfielders stay in middle band [MidLow, MidHigh]
    ( (Role = midfield, FinalX2 > MidHigh) -> FinalX3 is MidHigh ;
      (Role = midfield, FinalX2 < MidLow)  -> FinalX3 is MidLow  ;
      FinalX3 is FinalX2 ),

    % CASE 5: goalkeeper stays near own goal line
    ( (Role = goalkeeper, Team = team1, FinalX3 > 10) -> FinalX4 is 10 ;
      (Role = goalkeeper, Team = team2, FinalX3 < 110) -> FinalX4 is 110 ;
      FinalX4 is FinalX3 ),

    % Only update if position actually changed
    ( (FinalX4 =\= X ; NewY =\= Y) ->
        retract(player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina)),
        assertz(player(Name, Team, Role, position(FinalX4, NewY), Kickpower, Speed, Stamina))
    ; true ).

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

    % Every players move first, then enforce boundary
    forall(
        player(Name,_,_,_,_,_,_),
        ( move_towards_ball(Name), running_boundary(Name) )
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
