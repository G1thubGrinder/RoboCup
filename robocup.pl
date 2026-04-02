%make predicate changable
:- dynamic player/7.
:- dynamic ball/1.
:- dynamic log_stream/1.
:- dynamic log_round_count/1.
:- dynamic ball_kicked/0.

%----------------------------------------------------------------------
% Field
%----------------------------------------------------------------------
field(size(120, 60)).

%----------------------------------------------------------------------
% Set up
%----------------------------------------------------------------------
start_one_round:- setup, init_log, simulate_round, finalize_log.

setup:-
    retractall(ball(position(_,_))),
    retractall(player(_,_,_,_,_,_,_)),
    
    field(size(FieldW, FieldH)),
    BallX is FieldW // 2,
    BallY is FieldH // 2,
    assertz(ball(position(BallX, BallY))),

    % work for niner to list the football player
    % player(Name, Team, Role, position(X,Y), Kickpower, Speed, Stamina)

    % team1 2-3-1 on left field side
    % Forwards (X=50, spread Y: 15, 30, 45)
   
    assertz(player(ronaldo,     team1, forward,    position(50, 30), 20, 10, 100)),
   
    % Midfielders (X=35, spread Y: 15, 30, 45)
    assertz(player(modric,   team1, midfield,   position(35, 15), 40, 8,  100)),
    assertz(player(casemiro, team1, midfield,   position(35, 30), 20, 10, 100)),
    assertz(player(kroos,    team1, midfield,   position(35, 45), 10, 2,  100)),
    % Defenders (X=15, spread Y: 10, 23, 37, 50)
    assertz(player(varane,   team1, defender,   position(15, 23), 10, 6,  100)),
    assertz(player(ramos,    team1, defender,   position(15, 37), 10, 6,  100)),
    % Goalkeeper (X=3, centre Y=30)
    assertz(player(navas,    team1, goalkeeper, position(1,  30), 10, 2,  100)),


    % team2 2-3-1 on right field side
    % Forwards (X=70, spread Y: 15, 30, 45) — attack toward X=0
    assertz(player(suarez,       team2, forward,    position(70, 30), 45, 10, 100)),
   
    % Midfielders (X=85, spread Y: 15, 30, 45)
    assertz(player(iniesta,     team2, midfield,   position(85, 15), 30, 8,  100)),
    assertz(player(busquets,    team2, midfield,   position(85, 30), 20, 7,  100)),
    assertz(player(xavi,        team2, midfield,   position(85, 45), 30, 7,  100)),
    % Defenders (X=105, spread Y: 10, 23, 37, 50)
  
    assertz(player(pique,       team2, defender,   position(105, 23), 10, 6, 100)),
    assertz(player(mascherano,  team2, defender,   position(105, 37), 10, 6, 100)),
  
    % Goalkeeper (X=117, centre Y=30)
    assertz(player(bravo,       team2, goalkeeper, position(119, 30), 10, 2, 100)),

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
goal_position(team1, position(FieldW, GoalY)) :-
    field(size(FieldW, FieldH)), GoalY is FieldH // 2.
goal_position(team2, position(0, GoalY)) :-
    field(size(_, FieldH)), GoalY is FieldH // 2.

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

% add the running boundary, but where.........
move_towards_ball(Name):-
    player(Name,Team,Role,position(X1,Y1),Kickpower,Speed,Stamina),
    ball(position(BX,BY)),
    XDiff is BX - X1,
    YDiff is BY - Y1,
    % Effective speed degrades linearly with stamina
    EffectiveSpeed is max(1, round(Speed * Stamina / 100)),
    calculate_x_y_distance(EffectiveSpeed, XDiff, YDiff, XDis, YDis),
    NewX is X1 + XDis,
    NewY is Y1 + YDis,
    % Drain stamina by distance moved, clamp to 0
    Moved is round(sqrt(XDis^2 + YDis^2)),
    NewStamina is max(0, Stamina - Moved),
    retract(player(Name, Team, Role, position(X1,Y1), Kickpower, Speed, Stamina)),
    assertz(player(Name, Team, Role, position(NewX,NewY), Kickpower, Speed, NewStamina)),
    format(' ~w to (~w, ~w) sta:~w |', [Name, NewX, NewY, NewStamina]).

%----------------------------------------------------------------------
% Player attempt to kicking the ball
%----------------------------------------------------------------------

kick_ball(Name):-
    player(Name,Team,_,position(X1,Y1),Kickpower,Speed,Stamina),
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

    % Effective kickpower degrades linearly with stamina
    EffectiveKick is max(1, round(Kickpower * Stamina / 100)),
    % Calculate the final position of the ball based on the kicking power
    calculate_x_y_distance(EffectiveKick, XDiff, YDiff, XDis, YDis),
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
    field(size(FieldW, FieldH)),
    GoalY    is FieldH // 2,
    GoalLow  is GoalY - 3,
    GoalHigh is GoalY + 3,
    ball(position(BX, BY)),
    ((BX >= FieldW, BY >= GoalLow, BY =< GoalHigh) ->
        write('***Goal for team1***');
    (BX =< 0, BY >= GoalLow, BY =< GoalHigh) ->
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
    retractall(ball_kicked),
    forall(
        player(Name, _, _, _, _, _, _),
        (
            move_towards_ball(Name),
            running_boundary(Name),
            ( (\+ ball_kicked, kick_ball(Name)) -> assertz(ball_kicked) ; true )
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
    round_simulation(NewRoundCount).

% need to work on midield, and forwar
% player(Name, Team, Role, position(X,Y), Kickpower, Speed, Stamina)
% deal with atribute Role, position.

running_boundary(Name) :-
    field(size(FieldW, FieldH)),
    HalfW  is FieldW // 2,
    MidLow is FieldW // 4,
    MidHigh is (3 * FieldW) // 4,
    player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina),

    % FIRST CASE: clamp to field boundaries
    ( X < 0      -> NewX is 0      ; X > FieldW -> NewX is FieldW ; NewX is X ),
    ( Y < 0      -> NewY is 0      ; Y > FieldH -> NewY is FieldH ; NewY is Y ),

    % SECOND CASE: defenders must stay in their own half
    ( (Role = defender, Team = team1, NewX > HalfW) -> FinalX is HalfW ;
      (Role = defender, Team = team2, NewX < HalfW) -> FinalX is HalfW ;
      FinalX is NewX ),

    % THIRD CASE: forwards must stay in the attacking half
    ( (Role = forward, Team = team1, FinalX < HalfW) -> FinalX2 is HalfW ;
      (Role = forward, Team = team2, FinalX > HalfW) -> FinalX2 is HalfW ;
      FinalX2 is FinalX ),

    % FOURTH CASE: midfielders must stay in the middle band [MidLow, MidHigh]
    ( (Role = midfield, FinalX2 > MidHigh) -> FinalX3 is MidHigh ;
      (Role = midfield, FinalX2 < MidLow)  -> FinalX3 is MidLow  ;
      FinalX3 is FinalX2 ),

    % Only update the player record if the position actually changed
    ( (FinalX3 =\= X ; NewY =\= Y) ->
        retract(player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina)),
        assertz(player(Name, Team, Role, position(FinalX3, NewY), Kickpower, Speed, Stamina))
    ; true ).
