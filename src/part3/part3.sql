-- Функция, возвращающая таблицу TransferredPoints в более человекочитаемом виде

CREATE OR REPLACE FUNCTION fnc_transferred_points() RETURNS TABLE(Peer1 varchar, Peer2 varchar, PointsAmount integer)
AS $$ SELECT Peer1, Peer2, sum(PointsChange) AS PointsChange
FROM (
    SELECT checkingpeer AS Peer1, checkedpeer AS Peer2, pointsamount AS PointsChange FROM transferredpoints
UNION
SELECT checkedpeer AS Peer1, checkingpeer AS Peer2, 0-pointsamount AS PointsChange FROM transferredpoints) AS f 
GROUP BY Peer1, Peer2
ORDER BY Peer1, Peer2; $$
LANGUAGE SQL;

SELECT *
FROM fnc_transferred_points();

-- 2) Функция, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
-- TODO Проверить Одна задача может быть успешно выполнена несколько раз. В таком случае в таблицу включать все успешные проверки.
CREATE OR REPLACE FUNCTION fnc_XP_per_project() RETURNS TABLE(Peer varchar, Task varchar, XP integer)
AS $$ SELECT  peers.nickname AS Peer, checks.task AS Task, xp.xpamount AS XP FROM xp
JOIN checks ON xp."Check"=checks.id
JOIN peers ON checks.peer=peers.nickname $$
LANGUAGE SQL;

SELECT *
FROM fnc_XP_per_project();

-- 3) Функция, определяющая пиров, которые не выходили из кампуса в течение всего дня

CREATE OR REPLACE FUNCTION fnc_noexit_peers_ondate(ondate date) RETURNS TABLE(Peer varchar)
AS $$ SELECT Peer
FROM
(SELECT  timetracking.peer AS Peer, sum(state) AS in_out
FROM timetracking
WHERE date=ondate
GROUP BY Peer) AS ino
WHERE ino.in_out >3; $$
LANGUAGE SQL;

SELECT *
FROM fnc_noexit_peers_ondate('2023-02-01');

-- 4) Процедура для подсчёта изменений в количестве пир поинтов каждого пира по таблице TransferredPoints

CREATE OR REPLACE PROCEDURE proc_peer_points_change(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
    SELECT Peer, sum(PointsChange) AS PointsChange
        FROM (
            SELECT checkingpeer AS Peer, pointsamount AS PointsChange FROM transferredpoints
        UNION ALL
        SELECT checkedpeer AS Peer, 0-pointsamount AS PointsChange FROM transferredpoints) AS f 
        GROUP BY Peer
        ORDER BY PointsChange DESC;
END;
$$ LANGUAGE plpgsql;
BEGIN; 
CALL proc_peer_points_change('res');
FETCH ALL FROM "res";
END;

-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3

CREATE OR REPLACE PROCEDURE proc_peer_points_change_by_func(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
    SELECT Peer1 AS Peer, SUM(pointsamount) AS PointsChange FROM fnc_transferred_points()
GROUP BY fnc_transferred_points.Peer1
ORDER BY PointsChange DESC;
END;
$$ LANGUAGE plpgsql;

BEGIN; 
CALL proc_peer_points_change_by_func('res');
FETCH ALL FROM "res";
END;

-- 6) Определить самое часто проверяемое задание за каждый день

CREATE OR REPLACE PROCEDURE proc_most_checked_task(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
        WITH checks_count AS (SELECT date AS Day, task AS Task, COUNT(task) 
        FROM checks
        GROUP BY date, task
        ORDER BY count),
        sort_checks AS (SELECT Day, Task, ROW_NUMBER() OVER(partition BY Day ORDER BY count DESC) 
        FROM checks_count)
        SELECT Day, Task FROM sort_checks
        WHERE row_number =1;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_most_checked_task('res');
-- FETCH ALL FROM "res";
-- END;

select date, task, count(2) cnt
  from checks
 group by date, task
 having (date,count(1))=
  (
   select date, count(1) from checks
    where task =(select date from checks group by date order by count(1) desc limit 1)
    group by date, task
    order by count(2) desc
)

-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания

CREATE OR REPLACE PROCEDURE proc_peer_closed_block(task_block varchar, res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
        SELECT title 
        FROM tasks
        WHERE title ~ CONCAT('^', task_block, '[0-9]+_');
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_peer_closed_block('SQL', 'res');
-- FETCH ALL FROM "res";
-- END;

SELECT * FROM p2p
JOIN checks ON p2p."Check" = checks.id
WHERE state = 'Success';

-- 8) Определить, к какому пиру стоит идти на проверку каждому обучающемуся

CREATE OR REPLACE PROCEDURE proc_recomend_peer_for_checks(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
WITH fr AS (SELECT peer1, peer2 FROM friends
            UNION
            (SELECT peer2 AS peer1, peer2 AS peer1 FROM friends)),
    rec AS (SELECT peer2, recommendedpeer, count(recommendedpeer) FROM fr
        JOIN recommendations ON recommendations.peer = fr.peer1
        GROUP BY fr.peer2, recommendedpeer
        ORDER BY peer2, count DESC),
    recom AS (SELECT peer2, recommendedpeer, ROW_NUMBER() OVER(partition BY peer2 ORDER BY count DESC) FROM rec
        WHERE peer2 != recommendedpeer) 
    SELECT peer2, recommendedpeer from recom
    WHERE row_number =1;
END;
$$ LANGUAGE plpgsql;
BEGIN; 
CALL proc_recomend_peer_for_checks('res');
FETCH ALL FROM "res";
END;

-- 9) Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному
-- TODO объединить строки по блокам

CREATE OR REPLACE PROCEDURE proc_peer_trabajar_para_dos_blocos(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
WITH num_peers AS (SELECT COUNT(peers.nickname) as num FROM peers),
     block1 AS (SELECT peer, 1 AS block1 FROM checks
                WHERE task~ CONCAT('^', 'SQL', '[0-9]+_')),
     block2 AS  (SELECT peer, 1 AS block2 FROM checks
                WHERE task~ CONCAT('^', 'C', '[0-9]+_')),
     peer_by_block AS (SELECT COALESCE(block1.peer, block2.peer) as peername, block1, block2, 
                       COALESCE(block1.block1, block2.block2) as bothBlock
                       FROM block1
FULL  JOIN block2 ON block1.peer = block2.peer
GROUP BY peername, block1.block1, block2.block2)
SELECT count(peer_by_block.block1)*100/num_peers.num AS StartedBlock1, 
count(peer_by_block.block2)*100/num_peers.num AS StartedBlock1, 
count(peer_by_block.bothBlock)*100/num_peers.num AS StartedBothBlocks, 
100-count(peer_by_block.bothBlock)*100/num_peers.num AS DidntStartAnyBlock
FROM peer_by_block,num_peers
GROUP BY num_peers.num, peer_by_block.block1; 
END;
$$ LANGUAGE plpgsql;
BEGIN; 
CALL proc_peer_trabajar_para_dos_blocos('res');
FETCH ALL FROM "res";
END;

-- 10) Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения

CREATE OR REPLACE PROCEDURE proc_peer_checks_in_birthday(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
        WITH pr AS (SELECT * FROM checks 
        JOIN peers ON checks.peer = peers.nickname 
        WHERE EXTRACT(MONTH FROM checks.date) = EXTRACT(MONTH FROM peers.birthday) AND EXTRACT(DAY FROM checks.date) = EXTRACT(DAY FROM peers.birthday)),
        success AS (SELECT COUNT(case state when 'Success' then 1 else null end) FROM pr
        JOIN p2p ON p2p."Check" = pr.id), 
        failure AS (SELECT COUNT(case state when 'Failure' then 1 else null end) FROM pr
        JOIN p2p ON p2p."Check" = pr.id)
        SELECT round(sum(success.count)/(sum(success.count)+sum(failure.count))*100, 0),
        round(sum(failure.count)/(sum(success.count)+sum(failure.count))*100, 0)
        FROM success, failure;
END;
$$ LANGUAGE plpgsql;
BEGIN; 
CALL proc_peer_checks_in_birthday('res');
FETCH ALL FROM "res";
END;
