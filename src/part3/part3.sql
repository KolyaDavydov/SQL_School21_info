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
-- TODO проверить, может ли пир приходить и уходить в разные дни или стачала уйти, а потом прийти в кампус

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
        UNION
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
-- TODO расходятся результаты с частью 4
CREATE OR REPLACE PROCEDURE proc_peer_points_change_by_func(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
    SELECT Peer1 AS Peer, SUM(pointsamount) AS PointsChange FROM fnc_transferred_points()
GROUP BY fnc_transferred_points.Peer1
ORDER BY PointsChange DESC;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_peer_points_change_by_func('res');
-- FETCH ALL FROM "res";
-- END;

-- 6) Определить самое часто проверяемое задание за каждый день

CREATE OR REPLACE PROCEDURE proc_peer_points_change_by_func(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
        SELECT date AS Day, task AS Task, COUNT(task) 
        FROM checks
        GROUP BY date, task;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_peer_points_change_by_func('res');
-- FETCH ALL FROM "res";
-- END;

select date, task, count(2) cnt
  from checks
 group by date, task
 having (date,count(1))=
  (
   select date, count(1) from checks
    where date =(select date from checks group by date order by count(1) desc limit 1)
    group by date, task
    order by count(1) desc
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

