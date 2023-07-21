--ПРОЕКТ: Анализ сервиса вопросов и ответов по программированию (база данных StackOverflow)--

/* 1. ЧТО НУЖНО:
Сколько в среднем очков получает пост каждого пользователя?
Сформировать таблицу из следующих полей:
- заголовок поста;
- идентификатор пользователя;
- число очков поста;
- среднее число очков пользователя за пост, округлить до целого числа.
Не учитывать посты без заголовка, а также те, что набрали ноль очков.*/ 

SELECT title, user_id, score, 
    ROUND(AVG(score) OVER(PARTITION BY user_id))
FROM stackoverflow.posts
WHERE title IS NOT NULL AND score!=0


/* 2. ЧТО НУЖНО:
Посчитать ежедневный прирост новых пользователей в ноябре 2008 года. 
Сформировать таблицу с иснформацией:
- номер дня;
- число пользователей, зарегистрированных в этот день;
- сумму пользователей с накоплением. */ 

SELECT DISTINCT EXTRACT(DAY FROM creation_date) as day,
        COUNT(id) OVER( PARTITION BY EXTRACT (DAY FROM creation_date)) as count,
        COUNT(id) OVER( ORDER BY EXTRACT (DAY FROM creation_date)) as count_sum
FROM stackoverflow.users 
WHERE DATE_TRUNC('month', creation_date)::date = '2008-11-01' 

/* 3. ЧТО НУЖНО:
Написать запрос, который выгрузит данные о пользователях из США. 
Разделить пользователей на три группы в зависимости от количества просмотров их профилей:
- пользователям с числом просмотров больше либо равным 350 присвойте группу 1;
- пользователям с числом просмотров меньше 350, но больше либо равно 100 — группу 2;
- пользователям с числом просмотров меньше 100 — группу 3.
Отобразить лидеров каждой группы — пользователей, которые набрали максимальное число просмотров в своей группе.
 Вывести поля с идентификатором пользователя, группой и количеством просмотров. 
Отсортировать таблицу по убыванию просмотров, а затем по возрастанию значения идентификатора.*/ 

WITH q1 AS(
    SELECT id, views,
        CASE
            WHEN views>=350 THEN 1
            WHEN views>=100 THEN 2
            ELSE 3
        END as gr

    FROM stackoverflow.users 
    WHERE location like '%United States%' AND views!=0
    ),
q2 AS (    
    SELECT  gr, MAX(views) as max
    FROM q1 
    GROUP BY gr
)

SELECT q1.id, q1.gr, q1.views
FROM q1
    INNER JOIN q2 ON q1.gr=q2.gr
WHERE q1.views = q2.max
ORDER BY 3 DESC, 1


/* 4. ЧТО НУЖНО:
Используя данные о постах, вывести несколько полей:
- идентификатор пользователя, который написал пост;
- дата создания поста;
- количество просмотров у текущего поста;
- сумму просмотров постов автора с накоплением.
Данные в таблице отсортировать по возрастанию идентификаторов пользователей,
 а данные об одном и том же пользователе — по возрастанию даты создания поста.*/

SELECT p.user_id, p.creation_date, p.views_count,
    SUM(p.views_count) OVER(PARTITION BY user_id ORDER BY creation_date)
FROM  stackoverflow.posts AS p
ORDER BY user_id, creation_date

/* 5. ЧТО НУЖНО:

Выгрузить данные активности пользователя, который опубликовал больше всего постов за всё время. 
Вывести данные за октябрь 2008 года в таком виде:
- номер недели;
- дата и время последнего поста, опубликованного на этой неделе.*/

WITH q1 AS (
    SELECT DISTINCT user_id, 
            COUNT(id) OVER(PARTITION BY user_id)
    FROM stackoverflow.posts 
    ORDER BY 2 DESC
    LIMIT 1
    )

SELECT DISTINCT EXTRACT(WEEK FROM p.creation_date),
        LAST_VALUE(p.creation_date) OVER(PARTITION BY EXTRACT(WEEK FROM p.creation_date)
                                         ORDER BY p.creation_date
                                         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                                        )
FROM stackoverflow.posts AS p
    INNER JOIN q1 ON p.user_id=q1.user_id
WHERE EXTRACT(MONTH FROM p.creation_date) = 10

/* 6. ЧТО НУЖНО:
Для каждого пользователя, который написал хотя бы один пост, 
найти интервал между регистрацией и временем создания первого поста. 
Отобразить:
- id пользователя;
- разницу во времени между регистрацией и первым постом.*/

SELECT DISTINCT p.user_id,
        FIRST_VALUE(p.creation_date) OVER(PARTITION BY p.user_id 
                                          ORDER BY p.creation_date
                                         ) - u.creation_date as delta
FROM stackoverflow.posts AS p
        INNER JOIN stackoverflow.users AS u ON p.user_id= u.id

/* 7. ЧТО НУЖНО:
На сколько процентов менялось количество постов ежемесячно с 1 сентября по 31 декабря 2008 года? 
Отобразить таблицу со следующими полями:
- номер месяца;
- количество постов за месяц;
- процент, который показывает, насколько изменилось количество постов в текущем месяце по сравнению с предыдущим.
Округлить значение процента до двух знаков после запятой.*/

WITH q1 AS (
    SELECT DISTINCT EXTRACT(MONTH FROM creation_date) as month,
        COUNT(id) OVER (PARTITION BY DATE_TRUNC('month', creation_date)::date) as count

    FROM stackoverflow.posts 
    WHERE DATE_TRUNC('day', creation_date)::date BETWEEN '2008-09-01' AND '2008-12-31'
)

SELECT *,
    ROUND((count::numeric/LAG(count) OVER(ORDER BY month)-1)*100.0,2)
FROM q1
