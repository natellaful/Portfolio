
/* 
Task.  https://www.codewars.com/kata/62bf7e378e54a4003e8c3a21
 Fetch the 10 best teams with their aggregated team scores (only considering the top 5 scores per team) 
and also the top 5 team members each with their respective score (ordered by highest score first) within the team. 
*/

--MY SOLUTION

WITH q1 AS (
  SELECT
    t.name   AS team_name,
    tm.score AS member_score,
    CONCAT(tm.name,' (', tm.score,')') AS members,
    ROW_NUMBER(*) OVER(PARTITION BY t.id ORDER BY tm.score DESC, tm.id) AS rank,
    t.id
  FROM teams t
  JOIN team_members tm ON tm.team_id = t.id
  ORDER BY 1,4
),
q2 AS (
  SELECT team_name,
      SUM(member_score) AS team_score, 
      STRING_AGG(members,', ') AS top_members
  FROM q1
  WHERE rank<6
  GROUP BY team_name, id
  ORDER BY team_score DESC, id
  LIMIT 10
)
SELECT RANK(*) OVER(ORDER BY team_score DESC) AS team_rank, *
FROM q2

/* Calculating Month-Over-Month Percentage Growth Rate. Task. https://www.codewars.com/kata/589e0837e10c4a1018000028

Given a posts table that contains a created_at timestamp column write a query that returns a first date of the month,
  a number of posts created in a given month and a month-over-month growth rate.

The resulting set should be ordered chronologically by date.
*/
WITH q1 AS (
    SELECT DISTINCT DATE_TRUNC('month',created_at)::date AS date,
          COUNT(*) OVER(PARTITION BY DATE_TRUNC('month', created_at)::date) AS count
    FROM posts 
    ORDER BY date
  )

SELECT date, count,
      CASE WHEN count::numeric/LAG(count) OVER () *100.0-100 IS NULL THEN NULL
        ELSE CONCAT(ROUND(count::numeric/LAG(count) OVER () *100.0-100, 1 ), '%')
      END AS percent_growth
FROM q1

/* Challenge: Two actors who cast together the most. Task. https://www.codewars.com/kata/5818bde9559ff58bd90004a2

  Find two actors who cast together the most and list titles of only those movies they were casting together. Order the result set alphabetically by the movie title.
*/
WITH q1 AS (
  SELECT fa1.actor_id AS id1,  fa2.actor_id AS id2
  FROM film_actor AS fa1 
    INNER JOIN film_actor AS fa2 ON fa1.film_id = fa2.film_id
  WHERE fa1.actor_id <>fa2.actor_id 
        AND fa1.actor_id < fa2.actor_id 
  GROUP BY 1,2
  ORDER BY COUNT(fa1.film_id) DESC
  LIMIT 1
  )
SELECT
        CONCAT_WS(' ',a1.first_name,a1.last_name) AS first_actor,
        CONCAT_WS(' ', a2.first_name,a2.last_name) AS second_actor,
         f.title
FROM  film_actor AS fa1 
    INNER JOIN film_actor AS fa2 ON fa1.film_id = fa2.film_id
    INNER JOIN q1 ON q1.id1 = fa1.actor_id  AND q1.id2 = fa2.actor_id
    INNER JOIN actor AS a1 ON a1.actor_id = fa1.actor_id
    INNER JOIN actor AS a2 ON a2.actor_id = fa2.actor_id
    INNER JOIN film AS f ON f.film_id = fa1.film_id
WHERE fa1.actor_id = q1.id1 AND fa2.actor_id = q1.id2
ORDER BY 3
