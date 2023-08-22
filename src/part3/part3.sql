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
-- TODO дописать с запросом
CREATE OR REPLACE PROCEDURE peer_points_change(
    INOUT Peer varchar DEFAULT '',
    INOUT PointsChange INTEGER DEFAULT 0
    ) AS $$
BEGIN
  SELECT checkingpeer, pointsamount FROM transferredpoints
  INTO Peer, PointsChange;
END
$$ LANGUAGE plpgsql;
CALL peer_points_change();

-- Запрос для процедуры
SELECT Peer, sum(PointsChange) AS PointsChange
FROM (
    SELECT checkingpeer AS Peer, pointsamount AS PointsChange FROM transferredpoints
UNION
SELECT checkedpeer AS Peer, 0-pointsamount AS PointsChange FROM transferredpoints) AS f 
GROUP BY Peer
ORDER BY PointsChange DESC;

-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
-- Запрос для процедуры
SELECT Peer1 AS Peer, SUM(pointsamount) AS PointsChange FROM fnc_transferred_points()
GROUP BY fnc_transferred_points.Peer1
ORDER BY PointsChange DESC;
-- 6) Определить самое часто проверяемое задание за каждый день
-- Запрос для процедуры
SELECT date AS Day, task AS Task, COUNT(task) FROM checks
GROUP BY date, task;
