-- 1.List the different dtypes of columns in table “ball_by_ball” (using information schema)
show tables;
desc ball_by_ball;

-- 2. What is the total number of run scored in 1st season by RCB (bonus : also include the extra runs using the extra runs table)
select sum(coalesce(r.extra_runs,0) + coalesce(b.runs_scored,0)) as total_runs
from ball_by_ball b
join Team t
on b.Team_Batting=t.Team_id
join Matches m
on b.Match_id= m.Match_id
left join Extra_Runs r 
on b.Match_id = r.Match_id
and b.Innings_No=r.Innings_No
and b.Ball_Id =r.Ball_Id
and b.Over_Id = r.Over_id
where lower(t.Team_Name) in ('rcb', 'Royal Challengers Bengaluru', 'Royal Challengers Bangalore')
and m.Season_Id=(select min(season_id) from matches)
group by t.team_name;

-- 3. How many players were more than age of 25 during 2014 ?
select count(*) as age_above_25
from Player
where ('2014'- year(DOB)) >25;

-- 4. How many matches did RCB win in season 2013 ? 
select count(*) as rcb_win
from Matches 
where year(Match_Date) ='2013' and Match_Winner in (select Team_id from Team where Team_Name in ('rcb', 'Royal Challengers Bengaluru', 'Royal Challengers Bangalore'));

-- 5. List top 10 players according to their strike rate in last 4 seasons
select p.player_name, sum(b.runs_scored) as total_runs
from ball_by_ball b 
join player p 
on b.striker = p.player_id
group by b.striker
order by total_runs desc
limit 10;

-- 6. What is the average runs scored by each batsman considering all the seasons?
select striker, avg(Runs_Scored) as avg_runs
from ball_by_ball
where striker is not null
group by striker;

-- 7. What are the average wickets taken by each bowler considering all the seasons?
with wkt_cnt as (select fielders, count(player_out) as wicket_count
from Wicket_Taken
where fielders is not null
group by fielders)
select fielders as bowler, wicket_count/(select sum(wicket_count) from wkt_cnt) as average_wickets
from wkt_cnt;

-- 8. List all the players who have average runs scored greater than overall average and who have taken wickets greater than overall average
with player_batting as(select b.striker as player_id,
sum(coalesce(b.runs_scored, 0)) as total_runs,
count(distinct b.match_id) as matches_played,
sum(coalesce(b.runs_scored, 0)) * 1.0 / count(distinct b.match_id) as avg_runs
from ball_by_ball b
group by b.striker),

player_bowling as (select b.bowler as player_id,
count(w.player_out) as total_wickets
from ball_by_ball b
left join wicket_taken w 
on b.match_id = w.match_id 
and b.innings_no = w.innings_no 
and b.over_id = w.over_id 
and b.ball_id = w.ball_id
and w.kind_out not in (3, 5, 9)
group by b.bowler),

overall_metrics as (select (select avg(avg_runs) from player_batting) as global_avg_runs,
(select avg(total_wickets) from player_bowling) as global_avg_wickets)

select p.player_name,
round(bat.avg_runs, 2) as player_avg_runs,
round(om.global_avg_runs, 2) as benchmark_avg_runs,
bowl.total_wickets as player_total_wickets,
round(om.global_avg_wickets, 2) as benchmark_wickets
from player_batting bat
join player_bowling bowl on bat.player_id = bowl.player_id
join player p on bat.player_id = p.player_id
cross join overall_metrics om
where bat.avg_runs > om.global_avg_runs
and bowl.total_wickets > om.global_avg_wickets
order by bat.avg_runs desc, bowl.total_wickets desc;

-- 9. Create a table rcb_record table that shows wins and losses of RCB in an individual venue.
 create table rcb_record as 
 select v.venue_name,t.team_name,
 case 
 when m.match_winner = 2 then 'win'
 when m.outcome_type =1 then 'no_result/tie'
 else 'loss'
 end as match_result
 from Matches m
 join venue v
 on m.venue_id = v.venue_id
 join team t
 on m.match_winner = t.team_id
 left join win_by w 
 on m.win_type = w.win_id
 where team_1 =2 or team_2=2
 order by venue_name;
 
 select * from rcb_record;
 
-- 10. What is the impact of bowling style on wickets taken.
select b.bowling_id,b.bowling_skill,o.out_name, row_number() over(partition by b.bowling_skill order by o.out_id) as rn
from bowling_style b
join wicket_taken w
on b.bowling_id = w.fielders
left join out_type o
on w.kind_out = o.out_id;

-- 11. Write the sql query to provide a status of whether the performance of the team better than the previous year performance on the basis of number of runs scored by the team in the season and number of wickets taken 
with season_runs as (select m.season_id, b.team_batting as team_id,
sum(coalesce(b.runs_scored,0)+coalesce(r.extra_runs,0)) as total_runs
from ball_by_ball b
join matches m
on b.match_id= m.match_id
left join Extra_Runs r 
on b.match_id = r.match_id
and b.innings_No=r.innings_No
and b.ball_Id =r.ball_Id
and b.over_Id = r.over_id
group by m.season_id,b.team_batting),

season_wickets as (select m.season_id,b.team_bowling as team_id,
count(w.player_out) as total_wickets
from ball_by_ball b
join matches m 
on b.match_id = m.match_id
left join wicket_taken w
on b.match_id = w.match_id
and b.innings_No=w.innings_No
and b.ball_Id =w.ball_Id
and b.over_Id = w.over_id
group by m.season_id,b.team_bowling),

team_season as (select s.season_year, r.team_id,t.team_name,r.total_runs,
coalesce(w.total_wickets,0) as total_wickets
from season_runs r
left join season_wickets w on r.season_id=w.season_id and r.team_id=w.team_id
join season s on r.season_id = s.season_id
join team t on r.team_id = t.team_id),

performance as (select season_year, team_name,total_runs,total_wickets,
lag(total_runs)over(partition by team_id order by season_year) as prev_runs,
lag(total_wickets)over(partition by team_id order by season_year) as prev_wkt
from team_season)

select season_year, team_name, total_runs, total_wickets,
coalesce(cast(prev_runs as char),'N/A') as prev_year_runs,
coalesce(cast(prev_wkt as char),'N/A') as prev_year_wickets,
case
when prev_runs is null or prev_wkt is null then 'No data'
when total_runs> prev_runs and total_wickets>prev_wkt then 'Good'
else 'Poor'
end as performance_status
from performance
order by team_name, season_year;


-- 13. Using SQL, write a query to find out average wickets taken by each bowler in each venue. Also rank the gender according to the average value.
select p.player_name as bowler_name,v.venue_name,
count(w.player_out) as total_wickets_taken,
count(distinct b.match_id) as total_matches_bowled,
round(count(w.player_out)*1.0/count(distinct b.match_id),2)as avg_wickets_per_match
from ball_by_ball b
join matches m 
on b.match_id=m.match_id
join venue v on m.venue_id = v.venue_id
join player p on b.bowler = p.player_id
left join wicket_taken w 
on b.match_id = w.match_id
and b.over_id = w.over_id
and b.ball_id = w.ball_id
and b.innings_no = w.innings_no
and w.kind_out not in (3,5,9)
group by p.player_id,p.player_name,v.venue_id,v.venue_name
order by avg_wickets_per_match desc;

-- 14. Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)
-- batman performance
select p.player_name, sum(b.runs_scored) as total_runs, s.season_year, count(ball_id) as ball_cnt
from ball_by_ball b
left join matches m
on b.match_id = m.match_id
left join season s 
on m.season_id = s.season_id
left join player p
on p.player_id = b.striker
group by b.striker, s.season_year;

-- bowler performance table 
select p.player_name as bowler_name, sum(b.runs_scored) as striker_runs, count(w.player_out) as wicket_cnt, count(b.ball_id) as ball_cnt, 
s.season_year
from ball_by_ball b
join matches m
on b.match_id = m.match_id
join season s 
on m.season_id = s.season_id
join player p
on p.player_id = b.bowler
left join wicket_taken w
on b.match_id = w.match_id
and b.over_id = w.over_id
and b.ball_id = w.ball_id
and b.innings_no = w.innings_no
group by p.player_name, s.season_year;

-- 15. Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 
-- batman performance
select p.player_name, sum(b.runs_scored) as total_runs, v.venue_id, count(ball_id) as ball_cnt
from ball_by_ball b
left join matches m
on b.match_id = m.match_id
left join venue v
on m.venue_id = v.venue_id
left join player p
on p.player_id = b.striker
group by b.striker, v.venue_id;

-- bowler performance table
select p.player_name as bowler_name, sum(b.runs_scored) as striker_runs, count(w.player_out) as wicket_cnt, count(b.ball_id) as ball_cnt, 
v.venue_id
from ball_by_ball b
join matches m
on b.match_id = m.match_id
join venue v
on m.venue_id = v.venue_id
join player p
on p.player_id = b.bowler
left join wicket_taken w
on b.match_id = w.match_id
and b.over_id = w.over_id
and b.ball_id = w.ball_id
and b.innings_no = w.innings_no
group by p.player_name, v.venue_id;

-- subjective
-- 1.How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?
select m.match_id,m.match_winner,v.venue_name, m.toss_winner, t.toss_name, w.win_type
from Matches m
left join venue v 
on m.venue_id = v.venue_id
left join toss_decision t 
on m.toss_decide = t.toss_id
left join win_by w 
on m.win_type = w.win_id;

-- 5.Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)
-- player win count
select p.player_id, pl.player_name, p.team_id, count(m.match_id) as total_matches,
  sum(case when p.team_id = m.match_winner then 1 else 0 end) as win_cnt
from Matches m 
join player_match p
on p.match_id = m.match_id
join player pl 
on pl.player_id = p.player_id
group by p.player_id, p.team_id, pl.player_name;


-- 8.Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.
select venue_name, team_name, 
    sum(case when match_result ='win' then 1 else 0 end) as wins,
    sum(case when match_result = 'no_result/tie' then 1 else 0 end) as tie,
    sum(case when match_result = 'loss' then 1 else 0 end) as losses
from rcb_record
where team_name = 'Royal Challengers Bangalore'
group by venue_name, team_name;

-- 9.Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.
-- match wise performance
with rcb_runs as (select m.match_id, t.team_id, t.team_name, sum(coalesce(b.runs_scored,0) + coalesce(e.extra_runs,0)) as total_runs, v.venue_name, m.toss_winner, s.season_year, s.season_id
from ball_by_ball b 
left join extra_runs e 
on b.match_id = e.match_id
and b.over_id = e.over_id
and b.ball_id = e.ball_id
and b.innings_no = e.innings_no
left join team t 
on b.team_batting = t.team_id
left join matches m  
on b.match_id = m.match_id
left join season s 
on m.season_id = s.season_id
left join venue v
on m.venue_id = v.venue_id
where lower(t.team_name) in ('rcb', 'royal challengers bangalore', 'Royal Challengers Bengaluru')
group by m.match_id,t.team_id, t.team_name, s.season_year, v.venue_name, m.toss_winner,s.season_id),

rcb_wickets as (select b.match_id, m.season_id,b.team_bowling as team_id,
count(w.player_out) as total_wickets
from ball_by_ball b
join matches m 
on b.match_id = m.match_id
left join wicket_taken w
on b.match_id = w.match_id
and b.innings_No=w.innings_No
and b.ball_Id =w.ball_Id
and b.over_Id = w.over_id
where b.team_bowling =2
group by b.match_id,m.season_id,b.team_bowling)

select r.match_id, r.season_year,r.team_name,r.total_runs, coalesce(w.total_wickets,0) as total_wickets, r.venue_name, r.toss_winner, mt.match_winner
from rcb_runs r
left join rcb_wickets w on r.season_id = w.season_id and r.team_id=w.team_id and r.match_id= w.match_id
left join matches mt
on r.match_id = mt.match_id;


-- 11.In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils" 
no match table











