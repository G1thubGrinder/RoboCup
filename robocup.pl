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
    assertz(player(ronaldo,    team1, forward,    position(50, 30), 30, 2.75, 100)),
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
    HalfW    is FieldW // 2,
    MidLow   is FieldW // 4,
    MidHigh  is (3 * FieldW) // 4,
    player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina),
    ball(position(BX, BY)),

    % CASE 1: clamp to field boundaries (always enforced)
    ( X < 0      -> NewX is 0      ; X > FieldW -> NewX is FieldW ; NewX is X ),
    ( Y < 0      -> NewY is 0      ; Y > FieldH -> NewY is FieldH ; NewY is Y ),

    % CASE 2: defender must keep 10-unit X gap from nearest same-team midfielder
    ( (Role = defender, Team = team1) ->
        findall(MX, player(_, team1, midfield, position(MX, _), _, _, _), MidXs),
        ( MidXs \= [], min_list(MidXs, MinMidX) ->
            MaxDefX is MinMidX - 10,
            ( NewX > MaxDefX -> FinalXD is MaxDefX ; FinalXD is NewX )
        ; FinalXD is NewX )
    ; (Role = defender, Team = team2) ->
        findall(MX, player(_, team2, midfield, position(MX, _), _, _, _), MidXs),
        ( MidXs \= [], max_list(MidXs, MaxMidX) ->
            MinDefX is MaxMidX + 10,
            ( NewX < MinDefX -> FinalXD is MinDefX ; FinalXD is NewX )
        ; FinalXD is NewX )
    ; FinalXD is NewX ),

    % CASE 3: forwards stay in attacking half — only if ball is NOT in their zone
    ( (Role = forward, Team = team1, FinalXD < HalfW, BX < HalfW) -> FinalX2 is HalfW ;
      (Role = forward, Team = team2, FinalXD > HalfW, BX > HalfW) -> FinalX2 is HalfW ;
      FinalX2 is FinalXD ),

    % CASE 4: midfielders stay in middle band — only if ball is NOT in restricted area
    ( (Role = midfield, FinalX2 > MidHigh, BX =< MidHigh) -> FinalX3 is MidHigh ;
      (Role = midfield, FinalX2 < MidLow,  BX >= MidLow)  -> FinalX3 is MidLow  ;
      FinalX3 is FinalX2 ),

    % CASE 5: goalkeeper X — proportional to ball distance
    %   Exception: if ball is inside the goalkeeper box, release constraint so GK
    %   can chase the rebound freely and kick it (boundary would otherwise pull them away)
    %   team1 box: X <= 20   |   team2 box: X >= 100
    ( Role = goalkeeper ->
        field(size(FieldW, _)),
        GKBoxX2 is FieldW - 20,
        ( (Team = team1, BX =< 20) ->
            FinalX4 is FinalX3              % ball in box — chase freely
        ; (Team = team2, BX >= GKBoxX2) ->
            FinalX4 is FinalX3              % ball in box — chase freely
        ; Team = team1 ->
            GKX is max(5,  min(20,  5   + round(BX * 15 / FieldW))),
            FinalX4 is GKX
        ;
            GKX is max(100, min(115, 115 - round((FieldW - BX) * 15 / FieldW))),
            FinalX4 is GKX
        )
    ;
        FinalX4 is FinalX3
    ),

    % CASE 6: Y-axis constraints per role
    ( Role = goalkeeper ->
        % Goalkeeper: snap to goal-third matching ball Y-third
        %   field thirds: top [0,20) → goal top Y=24, mid [20,40] → Y=30, bot (40,60] → Y=36
        ThirdH is FieldH // 3,
        ( BY < ThirdH         -> FinalY is 24   % top third  → top of goal
        ; BY =< 2 * ThirdH   -> FinalY is 30   % mid third  → centre of goal
        ;                        FinalY is 36   % bot third  → bottom of goal
        )
    ; (Role = defender ; Role = midfield) ->
        % Skip Y spacing if player is within kick range of the ball on Y axis,
        % so they are not pushed away before they can kick.
        KickRangeY is sqrt(Speed),
        YDistBall  is abs(BY - NewY),
        ( YDistBall =< KickRangeY ->
            FinalY is NewY          % close enough to ball — preserve position to allow kick
        ;
            % Not in kick range: enforce 5-unit spacing from same-role teammates
            findall(TY, (player(Other, Team, Role, position(_, TY), _, _, _), Other \= Name), TeamY),
            adjust_y_spacing(NewY, TeamY, 7, SpacedY),
            FinalY is max(0, min(FieldH, SpacedY))
        )
    ;
        % Forwards: just field clamp
        FinalY is NewY
    ),

    % Only update if position actually changed
    ( (FinalX4 =\= X ; FinalY =\= Y) ->
        retract(player(Name, Team, Role, position(X, Y), Kickpower, Speed, Stamina)),
        assertz(player(Name, Team, Role, position(FinalX4, FinalY), Kickpower, Speed, Stamina))
    ; true ).

% adjust_y_spacing(+Y, +TeammateYList, +MinDist, -FinalY)
% Push Y away from any teammate closer than MinDist on the Y axis.
adjust_y_spacing(Y, [], _, Y).
adjust_y_spacing(Y, [TY | Rest], MinDist, FinalY) :-
    Diff is Y - TY,
    AbsDiff is abs(Diff),
    ( AbsDiff < MinDist ->
        ( Diff >= 0 -> Adjusted is TY + MinDist ; Adjusted is TY - MinDist )
    ;
        Adjusted = Y
    ),
    adjust_y_spacing(Adjusted, Rest, MinDist, FinalY).

%----------------------------------------------------------------------
% Pass Target Logic
%----------------------------------------------------------------------

get_pass_target(Team, Role, TX, TY) :-
    findall(MX-MY, player(_, Team, Role, position(MX, MY), _, _, _), All),
    All \= [],
    random_member(MX-MY, All),
    TX = MX, TY = MY.

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

    % Every player moves in random order, then enforce boundary
    findall(N, player(N,_,_,_,_,_,_), AllPlayers),
    random_permutation(AllPlayers, ShuffledMove),
    forall(
        member(Name, ShuffledMove),
        ( move_towards_ball(Name), running_boundary(Name) )
    ),

    % Tackle phase: defenders in random order attempt to dispossess opponents
    retractall(ball_kicked),
    retractall(last_kick(_)),
    findall(N, player(N,_,defender,_,_,_,_), AllDef),
    random_permutation(AllDef, ShuffledDef),
    forall(
        member(Name, ShuffledDef),
        ( (\+ ball_kicked, tackle_attempt(Name)) -> assertz(ball_kicked) ; true )
    ),

    % Record whether a tackle happened this tick before kick phase clears ball_kicked
    ( ball_kicked -> TackledThisTick = true ; TackledThisTick = false ),

    ( TackledThisTick = true, last_kick(Tackler) ->
        atomic_list_concat(['tackle:', Tackler], ActionTackle)
    ; ActionTackle = ''
    ),

    % Kick phase: random order, only runs if no tackle happened
    ( TackledThisTick = false ->
        retractall(ball_kicked),
        findall(N, player(N,_,_,_,_,_,_), AllKick),
        random_permutation(AllKick, ShuffledKick),
        forall(
            member(Name, ShuffledKick),
            ( (\+ ball_kicked, kick_ball(Name)) -> assertz(ball_kicked) ; true )
        )
    ; true ),

    ( TackledThisTick = false, last_kick(Kicker) ->
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
        build_action([ActionTackle, ActionKick, ActionSave, ActionGoal], Action),
        log_time_frame(GameNum, Ticks, Action),
        true   % round ends here, return to round_simulation
    ; ball_out_of_field(Team) ->
        atomic_list_concat(['ball_out:', Team], ActionOut),
        build_action([ActionTackle, ActionKick, ActionSave, ActionOut], Action),
        log_time_frame(GameNum, Ticks, Action),
        goal_kick_back(Team),
        NextTick is Ticks - 1,
        simulate_round(GameNum, NextTick)
    ;
        build_action([ActionTackle, ActionKick, ActionSave], Action),
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

%----------------------------------------------------------------------
% Tackle (defenders only)
%----------------------------------------------------------------------

opponent_team(team1, team2).
opponent_team(team2, team1).

tackle_radius(4).
tackle_sigma(2).

% tackle_attempt(+DefenderName)
% Succeeds when a defender is close enough to the ball AND an opponent is
% also in kick range of it. Clears the ball toward the defenders own goal.
tackle_attempt(Name) :-
    player(Name, Team, defender, position(DX, DY), _, _, _),
    ball(position(BX, BY)),

    % Defender must be within tackle radius
    tackle_radius(TackleR),
    DXDist is abs(BX - DX),
    DYDist is abs(BY - DY),
    DXDist =< TackleR,
    DYDist =< TackleR,

    % An opponent must also be in their kick range (they have the ball)
    opponent_team(Team, OppTeam),
    player(OppName, OppTeam, _, position(OX, OY), _, OppSpeed, _),
    OppKick is sqrt(OppSpeed),
    abs(BX - OX) =< OppKick,
    abs(BY - OY) =< OppKick,

    % Probability of success: Gaussian on distance (closer = higher chance)
    tackle_sigma(Sigma),
    Dist is sqrt((BX - DX)^2 + (BY - DY)^2),
    Prob is exp(-(Dist * Dist) / (2 * Sigma * Sigma)),
    random(Rnd),
    Rnd < Prob,

    % Success: clear ball toward own attacking goal
    goal_position(Team, position(TargetX, TargetY)),
    XDiff is TargetX - BX,
    YDiff is TargetY - BY,
    random(R2),
    KickpowerFactor is (4 * ((R2 - 0.5)^3) + 1),
    ActualKickpower is 55 * KickpowerFactor,
    calculate_x_y_distance(ActualKickpower, XDiff, YDiff, XDis, YDis),
    NewBX is BX + XDis,
    NewBY is BY + YDis,
    format('~n*** ~w (defender) TACKLES ~w! Ball cleared to (~w, ~w) ***~n',
           [Name, OppName, NewBX, NewBY]),
    retractall(ball(position(_, _))),
    assertz(ball(position(NewBX, NewBY))),
    retractall(last_kick(_)),
    assertz(last_kick(Name)).

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