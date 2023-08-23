/* 3-17. Определить для каждого месяца процент ранних входов
Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время (будем называть это общим числом входов). 
Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов). 
Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов. 
Формат вывода: месяц, процент ранних входов
 * */
DROP PROCEDURE IF EXISTS proc_percent_of_entry_early CASCADE;
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


/* 3-15. Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
Параметры процедуры: время, количество раз N. 
Формат вывода: список пиров
*/
DROP PROCEDURE IF EXISTS proc_peer_come_before CASCADE;
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

/* 3-14. Определить пира с наибольшим количеством XP
Формат вывода: ник пира, количество XP
*/
DROP PROCEDURE IF EXISTS proc_peer_max_xp CASCADE;
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