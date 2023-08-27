
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

-- SELECT *
-- FROM fnc_transferred_points();

-- 2) Функция, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP

CREATE OR REPLACE FUNCTION fnc_XP_per_project() RETURNS TABLE(Peer varchar, Task varchar, XP integer)
AS $$ SELECT  peers.nickname AS Peer, checks.task AS Task, xp.xpamount AS XP FROM xp
JOIN checks ON xp."Check"=checks.id
JOIN peers ON checks.peer=peers.nickname $$
LANGUAGE SQL;

-- SELECT *
-- FROM fnc_XP_per_project();

-- 3) Функция, определяющая пиров, которые не выходили из кампуса в течение всего дня

CREATE OR REPLACE FUNCTION fnc_noexit_peers_ondate(ondate date) RETURNS TABLE(Peer varchar)
AS $$ SELECT Peer
FROM
(SELECT  timetracking.peer AS Peer, sum(state) AS in_out
FROM timetracking
WHERE date=ondate
GROUP BY Peer) AS ino
WHERE ino.in_out =3; $$
LANGUAGE SQL;

-- SELECT *
-- FROM fnc_noexit_peers_ondate('2023-02-01');

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

-- BEGIN; 
-- CALL proc_peer_points_change('res');
-- FETCH ALL FROM "res";
-- END;

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

-- BEGIN; 
-- CALL proc_peer_points_change_by_func('res');
-- FETCH ALL FROM "res";
-- END;

-- 6) Определить самое часто проверяемое задание за каждый день

CREATE OR REPLACE PROCEDURE proc_most_checked_task(res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
        WITH checks_count AS (SELECT date AS Day, task AS Task, COUNT(task) 
        FROM checks
        GROUP BY date, task
        ORDER BY date)
        SELECT checks_count.day,
			checks_count.task
		FROM checks_count
			LEFT JOIN checks_count cc ON cc.task != checks_count.task
				and cc.day = checks_count.day AND cc.count > checks_count.count
		WHERE cc.day IS NULL;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_most_checked_task('res');
-- FETCH ALL FROM "res";
-- END;

-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания

CREATE OR REPLACE PROCEDURE proc_peer_closed_block(task_block varchar, res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
		WITH block AS (SELECT title 
									FROM tasks
									WHERE title ~ CONCAT('^', 'C', '[0-9]+_')),
						success AS (SELECT peer, task, date
									FROM p2p
									JOIN checks ON p2p."Check" = checks.id
									JOIN verter ON verter."Check" = checks.id
									WHERE p2p.state = 'Success'
									AND (verter.state = 'Success' OR verter.state = NULL))
					SELECT peer, date as Day FROM success
					WHERE task = (SELECT max(title) FROM block);
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_peer_closed_block('C', 'res');
-- FETCH ALL FROM "res";
-- END;

SELECT p2p.id, checks.peer, checks.task, row_number() over (partition by checks.peer order by checks.task) FROM p2p
JOIN checks ON p2p."Check" = checks.id
JOIN verter ON verter."Check" = checks.id
WHERE p2p.state = 'Success'
AND (verter.state = 'Success' OR verter.state = NULL);

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
    SELECT peer2 AS Peer, recommendedpeer from recom
    WHERE row_number =1;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_recomend_peer_for_checks('res');
-- FETCH ALL FROM "res";
-- END;

-- 9) Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному
-- TODO проверить откуда вторая строка в итоге без LIMIT

CREATE OR REPLACE PROCEDURE proc_peer_trabajar_para_dos_blocos(IN block1_name VARCHAR, block2_name VARCHAR, res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
WITH num_peers AS (SELECT COUNT(peers.nickname) as num FROM peers),
     block1 AS (SELECT peer, 1 AS block1 FROM checks
                WHERE task~ CONCAT('^', block1_name, '[0-9]+_')),
     block2 AS  (SELECT peer, 1 AS block2 FROM checks
                WHERE task~ CONCAT('^', block2_name, '[0-9]+_')),
     peer_by_block AS (SELECT COALESCE(block1.peer, block2.peer) as peername, block1, block2, 
                       COALESCE(block1.block1, block2.block2) as bothBlock
                       FROM block1
FULL  JOIN block2 ON block1.peer = block2.peer
GROUP BY peername, block1.block1, block2.block2)
SELECT Round(CAST(count(peer_by_block.block1) AS NUMERIC)*100/num_peers.num, 0) AS "StartedBlock1", 
Round(CAST(count(peer_by_block.block2) AS NUMERIC)*100/num_peers.num, 0) AS "StartedBlock2", 
Round(CAST(count(peer_by_block.bothBlock) AS NUMERIC)*100/num_peers.num, 0) AS "StartedBothBlocks", 
100-Round(CAST(count(peer_by_block.bothBlock) AS NUMERIC)*100/num_peers.num, 0) AS "DidntStartAnyBlock"
FROM peer_by_block,num_peers
GROUP BY num_peers.num, peer_by_block.block1 LIMIT 1; 
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_peer_trabajar_para_dos_blocos('SQL', 'C', 'res');
-- FETCH ALL FROM "res";
-- END;

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
        SELECT round(sum(success.count)/(sum(success.count)+sum(failure.count))*100, 0) AS "SuccessfulChecks",
        round(sum(failure.count)/(sum(success.count)+sum(failure.count))*100, 0) AS "UnsuccessfulChecks"
        FROM success, failure;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_peer_checks_in_birthday('res');
-- FETCH ALL FROM "res";
-- END;

-- 11) Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3

CREATE OR REPLACE PROCEDURE proc_peer_made_two_tasks_from_tree(IN task1_name VARCHAR, task2_name VARCHAR, task3_name VARCHAR, res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
WITH pr1 AS (SELECT peers.nickname FROM checks 
        JOIN peers ON checks.peer = peers.nickname
        JOIN p2p ON p2p."Check" = checks.id
		FULL JOIN verter ON verter."Check" = checks.id
		WHERE task =task1_name AND p2p.state = 'Success' 
		AND (verter.state = 'Success' OR verter.state = NULL)
		),
	pr2 AS (SELECT peers.nickname FROM checks 
        JOIN peers ON checks.peer = peers.nickname
        JOIN p2p ON p2p."Check" = checks.id
		FULL JOIN verter ON verter."Check" = checks.id
		WHERE task =task2_name AND p2p.state = 'Success' 
		AND (verter.state = 'Success' OR verter.state = NULL)
		),
	pr3 AS (SELECT peers.nickname FROM checks 
        JOIN peers ON checks.peer = peers.nickname
        JOIN p2p ON p2p."Check" = checks.id
		FULL JOIN verter ON verter."Check" = checks.id
		WHERE task =task3_name AND p2p.state = 'Success' 
		AND (verter.state = 'Success' OR verter.state = NULL)
		),
	pr12 AS (SELECT pr1.nickname FROM pr1		
			 JOIN pr2 ON pr1.nickname = pr2.nickname )
SELECT pr12.nickname FROM pr12
JOIN pr3 ON pr12.nickname != pr3.nickname;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_peer_made_two_tasks_from_tree('C2_SimpleBashUtils', 'C4_s21_math', 'C5_s21_decimal','res');
-- FETCH ALL FROM "res";
-- END;

/*3_12. Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач
То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей. 
Формат вывода: название задачи, количество предшествующих
*/
DROP PROCEDURE IF EXISTS proc_count_parent_tasks CASCADE;
CREATE OR REPLACE PROCEDURE proc_count_parent_tasks(refcurs REFCURSOR)
AS $$
	BEGIN
		OPEN refcurs FOR
			WITH RECURSIVE parent AS
				(SELECT
					(SELECT	title
					FROM tasks
					WHERE parenttask IS NULL) AS Task,
				0 AS PrevCount
				UNION ALL
				SELECT
					t.title,
					PrevCount + 1
				FROM parent p
				JOIN tasks t ON t."parenttask" = p.Task)
			SELECT *
			FROM parent;
	END;
$$ LANGUAGE plpgsql;

-- вызов процедуры для проверки 3.12
--  BEGIN;
-- 	CALL proc_count_parent_tasks('refcurs');
-- 	FETCH ALL FROM "refcurs";
--  END;

/* 3-13. Найти "удачные" для проверок дни. День считается "удачным", если в нем есть хотя бы N идущих подряд успешных проверки
Параметры процедуры: количество идущих подряд успешных проверок N. 
Временем проверки считать время начала P2P этапа. 
Под идущими подряд успешными проверками подразумеваются успешные проверки, между которыми нет неуспешных. 
При этом кол-во опыта за каждую из этих проверок должно быть не меньше 80% от максимального. 
Формат вывода: список дней
*/
DROP PROCEDURE IF EXISTS proc_lucky_day CASCADE;
CREATE OR REPLACE PROCEDURE proc_lucky_day(N int, refcurs REFCURSOR)
AS $$
	BEGIN
		OPEN refcurs FOR
			WITH result AS
				(SELECT
					checks.id AS checks_id,
					p2p.id AS p2p_id,
					date,
					p2p.time AS time,
					p2p.state AS p2p_state,
					verter.state AS vert_state,
					(xpamount * 100 / maxxp) AS percent_xp
				FROM checks
				JOIN p2p ON checks.id = p2p."Check"
				LEFT JOIN verter ON checks.id = verter."Check"
				LEFT JOIN xp ON p2p."Check" = xp."Check"
				JOIN tasks ON task = title
				WHERE p2p.state != 'Start' AND (verter.state = 'Success' OR verter.state = 'Failure' OR verter.state IS NULL)
				ORDER BY date, p2p.time),
            result_all AS
            	(SELECT
            		ROW_NUMBER() OVER (PARTITION BY (date) ORDER BY time) AS row_num,
            		*
            	FROM result),
            result_only_success AS
            	(SELECT
            		ROW_NUMBER() OVER (PARTITION BY (date) ORDER BY time) AS row2_num,
            		*
            	FROM result_all
            	WHERE p2p_state = 'Success' AND (vert_state = 'Success' OR vert_state IS NULL) AND percent_xp >= 80)
			SELECT date
			FROM result_only_success
			WHERE row2_num - row_num = 0
			GROUP BY date
			HAVING count(*) >= N;
	END;
$$ LANGUAGE plpgsql;
-- вызов процедуры для проверки 3.13
--  BEGIN;
--  	CALL proc_lucky_day(1, 'refcurs');
--  	FETCH ALL FROM "refcurs";
--  END;


/* 3-14. Определить пира с наибольшим количеством XP
Формат вывода: ник пира, количество XP
*/
-- DROP PROCEDURE IF EXISTS proc_peer_max_xp CASCADE;
CREATE OR REPLACE PROCEDURE proc_peer_max_xp(refcurs REFCURSOR DEFAULT 'refcurs')
AS $$
	BEGIN
		OPEN refcurs FOR
			SELECT
				peer,
				sum(xpamount) AS XP
			FROM xp
			JOIN checks ON xp."Check"=checks.id
			GROUP BY peer
			ORDER BY XP DESC
			LIMIT 1;
	END;
$$ LANGUAGE plpgsql;
-- вызов процедуры для проверки 3.14
-- BEGIN;
-- 	CALL proc_peer_max_xp();
-- 	FETCH ALL FROM "refcurs";
-- END;

/* 3-15. Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
Параметры процедуры: время, количество раз N. 
Формат вывода: список пиров
*/
-- DROP PROCEDURE IF EXISTS proc_peer_come_before CASCADE;
CREATE OR REPLACE PROCEDURE proc_peer_come_before(T time, M int, refcurs REFCURSOR DEFAULT 'refcurs')
AS $$
	BEGIN
		OPEN refcurs FOR
			SELECT peer
			FROM (SELECT
					peer,
					count(state) AS counts
				FROM timetracking
				WHERE state = 1 AND time < T
				GROUP BY peer) AS come_peer
			WHERE counts >= M;
	END;
$$ LANGUAGE plpgsql;

-- вызов процедуры для проверки 3.15
-- BEGIN;
--	 CALL proc_peer_come_before('09:00:00'::time, 1);
--	 FETCH ALL FROM "refcurs";
-- END;

/* 3-16. Определить пиров, выходивших за последние N дней из кампуса больше M раз
Параметры процедуры: количество дней N, количество раз M. 
Формат вывода: список пиров
*/
DROP PROCEDURE IF EXISTS proc_count_out_of_campus CASCADE;
CREATE OR REPLACE PROCEDURE proc_count_out_of_campus(N int, M int, refcurs REFCURSOR)
AS $$
	BEGIN
		OPEN refcurs FOR
			WITH left_campus AS (
				SELECT 
					peer,
					date
				FROM timetracking
				WHERE state = 2 AND (current_date - date) < N
				GROUP BY peer, date)
			SELECT peer FROM left_campus
			GROUP BY peer
			HAVING count(peer) > M;
	END;
$$ LANGUAGE plpgsql;

-- вызов процедуры для проверки 3.16
-- BEGIN;
-- 	CALL proc_count_out_of_campus(360, 1, 'refcurs');
-- 	FETCH ALL FROM "refcurs";
-- END;

/* 3-17. Определить для каждого месяца процент ранних входов
Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время (будем называть это общим числом входов). 
Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов). 
Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов. 
Формат вывода: месяц, процент ранних входов
 * */
-- DROP PROCEDURE IF EXISTS proc_percent_of_entry_early CASCADE;
CREATE OR REPLACE PROCEDURE proc_percent_of_entry_early(refcurs REFCURSOR)
AS $$
	BEGIN
		OPEN refcurs FOR -- открываем курсорную переменную для запроса
			WITH
				-- столбец со списком месяцев	
				list_month AS(
					SELECT generate_series('2023-01-01'::date, '2023-12-01'::date, '1 month') AS month),
				-- дата, время входя где месяц рождения совпадает с месяцем входа
				entry_birthday_in_month AS (
					SELECT
						date,
						time
					FROM timetracking t
					JOIN peers p ON t.peer = p.nickname 
					WHERE state = 1 AND (SELECT EXTRACT(MONTH FROM birthday)) = (SELECT EXTRACT(MONTH FROM date))), -- EXTRACT - функция даты и времени
				-- месяц, общее количество вхождений (у кого совпадают месяц др и месяц вхождения)
				entry_all AS (
					SELECT
						month,
						count(date) AS counts
					FROM list_month
					LEFT JOIN entry_birthday_in_month ON EXTRACT(MONTH FROM date) = EXTRACT(MONTH FROM month)
					GROUP BY MONTH
					ORDER BY month),
				-- месяц, количество ранних вхождений до 12:00 (у кого совпадают месяц др и месяц вхождения)
				entry_early AS (
					SELECT
						month,
						count(date) AS counts
					FROM list_month
					LEFT JOIN entry_birthday_in_month ON EXTRACT(MONTH FROM date) = EXTRACT(MONTH FROM month)
					WHERE time < '12:00:00'::TIME
					GROUP BY month
					ORDER BY month)
				-- конечная таблица (месяц, процент раннего вхождения)
			SELECT
				TO_CHAR(entry_all.month, 'Month') AS Month,
				CASE entry_all.counts
					WHEN 0
					THEN 0
					ELSE round(coalesce(entry_early.counts, 0)::NUMERIC / entry_all.counts::NUMERIC * 100)
				END AS entry_earlyentry_all
			FROM entry_all
			LEFT JOIN entry_early ON entry_all.month = entry_early.month;
	END;
$$ LANGUAGE plpgsql;
-- вызов процедуры с курсором в качестве аргумента должен выполнятся обязательно в одной транзакции
-- FETCH получить результат запроса через курсор
-- курсор посути ссылка на область памяти где храниться результат запроса
-- BEGIN;
-- 	CALL proc_percent_of_entry_early('refcurs');
-- 	FETCH ALL FROM "refcurs";
-- END;
