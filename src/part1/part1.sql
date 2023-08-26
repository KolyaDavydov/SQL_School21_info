-- Создание БД и подключение к ней
-- 'psql -U postgres' (заходим в постгрес под пользователем postgres)
-- 'CREATE DATABASE s21_info;' (создаем базу данных)
-- '\c s21_info' (подключаемся к базе данных)

-- СОздание таблиц со знаниями о школе 21. Интерпритация портала школы 21

/*
	Таблица Peers:
		- Ник пира
		- День рождения
 * */
CREATE TABLE IF NOT EXISTS Peers (
	Nickname varchar PRIMARY KEY,
	Birthday date
);

/*
	Таблица Tasks:
		- Название задания
		- Название задания, являющегося условием входа
		- Максимальное количество XP
 * */
CREATE TABLE IF NOT EXISTS Tasks(
	Title 		varchar PRIMARY KEY,
    ParentTask 	varchar,
    MaxXP      	integer CHECK (MaxXP > 0),
    
    FOREIGN KEY (ParentTask) REFERENCES Tasks (Title)
);

/*
	Статус проверки. Тип перечисления для статуса проверки:
		- Start - начало проверки
		- Success - успешное окончание проверки
		- Failure - неудачное окончание проверки
 * */

CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

/*
	Таблица Checks
		- ID
		- Ник пира
		- Название задания
		- Дата проверки
 * */
CREATE TABLE IF NOT EXISTS Checks(
	ID			integer		PRIMARY KEY,
	Peer		varchar,
	Task		varchar,
	Date		date,
	
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (Task) REFERENCES Tasks (Title)
);

/*
	Таблица P2P
		- ID
		- ID проверки
		- Ник проверяющего пира
		- Статус P2P проверки
		- Время
 * */
CREATE TABLE IF NOT EXISTS P2P(
	ID			integer		PRIMARY key,
	"Check"		integer,
	CheckingPeer varchar,
	State		check_status,
	Time		time,
	
	FOREIGN KEY ("Check") 		REFERENCES Checks (ID),
	FOREIGN KEY (CheckingPeer) 	REFERENCES Peers (Nickname)
);

/*
	Таблица Verter
		- ID
		- ID проверки
		- Статус проверки Verter'ом
		- Время
 * */
CREATE TABLE IF NOT EXISTS Verter(
	ID			integer		PRIMARY key,
	"Check"		integer,
	State		check_status,
	Time		time,
	
	FOREIGN KEY ("Check") REFERENCES Checks (ID)
);

/*
	Таблица TransferredPoints
		- ID
		- Ник проверяющего пира
		- Ник проверяемого пира
		- Количество переданных пир поинтов за всё время (только от проверяемого к проверяющему)
 * */
CREATE TABLE IF NOT EXISTS TransferredPoints(
	ID integer PRIMARY KEY,
	CheckingPeer	varchar,
	CheckedPeer		varchar,
	PointsAmount	integer,
	
    FOREIGN KEY (CheckingPeer)	REFERENCES Peers (Nickname),
    FOREIGN KEY (CheckedPeer)	REFERENCES Peers (Nickname)
);

/*
	Таблица Friends
		- ID
		- Ник первого пира
		- Ник второго пира
 * */
CREATE TABLE IF NOT EXISTS Friends(
	ID		integer	PRIMARY KEY,
	Peer1	varchar,
	Peer2	varchar,
	
   	FOREIGN KEY (Peer1) REFERENCES Peers (Nickname),
    FOREIGN KEY (Peer2) REFERENCES Peers (Nickname)
);

/*
	Таблица Recommendations
		- ID
		- Ник пира
		- Ник пира, к которому рекомендуют идти на проверку
 * */

CREATE TABLE IF NOT EXISTS Recommendations(
	ID				integer	PRIMARY KEY,
	Peer			varchar,
	RecommendedPeer	varchar,
	
    FOREIGN KEY (Peer) 				REFERENCES Peers (Nickname),
    FOREIGN KEY (RecommendedPeer) 	REFERENCES Peers (Nickname)
);

/*
	Таблица XP
		- ID
		- ID проверки
		- Количество полученного XP
 * */
CREATE TABLE IF NOT EXISTS XP(
	ID			integer	PRIMARY KEY,
	"Check"		integer,
	XPAmount	integer,
	
	FOREIGN KEY ("Check") REFERENCES Checks (ID)
);

/*
	Таблица TimeTracking
		- ID
		- Ник пира
		- Дата
		- Время
		- Состояние (1 - пришел, 2 - вышел)
 * */
CREATE TABLE IF NOT EXISTS TimeTracking(
	ID 		integer	PRIMARY KEY,
	Peer 	varchar,
	Date	date,
	Time	time,
	State 	int2,
	
	FOREIGN KEY (Peer) REFERENCES Peers (Nickname)
);



-- ЗАПОЛНЯЕМ ДАННЫМИ ТАБЛИЦЫ
INSERT INTO Peers (nickname, birthday)
	VALUES 	('name_1', '1970-01-01'),
			('name_2', '1980-02-01'),
			('name_3', '1990-03-01'),
			('name_4', '2000-02-01'),
			('name_5', '2005-04-01');

/* TASKS
Чтобы получить доступ к заданию, нужно выполнить задание,
являющееся его условием входа. Для упрощения будем считать,
что у каждого задания всего одно условие входа.
В таблице должно быть одно задание, у которого нет условия входа
(т.е. поле ParentTask равно null).
*/
INSERT INTO Tasks (title, parenttask,maxxp)
	VALUES	('C2_SimpleBashUtils', NULL, 250),
			('C3_s21_string+', 'C2_SimpleBashUtils', 500),
			('C4_s21_math', 'C2_SimpleBashUtils', 300),
			('C5_s21_decimal', 'C4_s21_math', 350),
			('C6_s21_matrix', 'C5_s21_decimal', 200),
			('C7_SmartCalc_v1.0', 'C6_s21_matrix', 500),
			('C8_3DViewer_v1.0', 'C7_SmartCalc_v1.0', 750),
			('DO1_Linux', 'C3_s21_string+', 300),
			('DO2_Linux Network', 'DO1_Linux', 250),
			('DO3_LinuxMonitoring v1.0', 'DO2_Linux Network', 350),
			('DO4_LinuxMonitoring v2.0', 'DO3_LinuxMonitoring v1.0', 350),
			('DO5_SimpleDocker', 'DO3_LinuxMonitoring v1.0', 300),
			('DO6_CICD', 'DO5_SimpleDocker', 300),
			('SQL1_Bootcamp', 'C8_3DViewer_v1.0', 1500),
			('SQL2_Info21 v1.0', 'SQL1_Bootcamp', 500),
			('SQL3_RetailAnalitycs v1.0', 'SQL2_Info21 v1.0', 600);

/* CHECKS
Описывает проверку задания в целом. Проверка обязательно включает в себя этап P2P и,
возможно, этап Verter. Для упрощения будем считать, что пир ту пир и автотесты,
относящиеся к одной проверке, всегда происходят в один день.
Проверка считается успешной, если соответствующий P2P этап успешен,
а этап Verter успешен, либо отсутствует. Проверка считается неуспешной,
хоть один из этапов неуспешен. То есть проверки, в которых ещё не завершился этап P2P,
или этап P2P успешен, но ещё не завершился этап Verter,
не относятся ни к успешным, ни к неуспешным.
*/
INSERT INTO Checks(id, peer, task, date) VALUES
		(1, 'name_1', 'C2_SimpleBashUtils', '2023-01-01'), -- пир успешно, вертер фэйл
		(2, 'name_1', 'C2_SimpleBashUtils', '2023-01-02'), -- пир успешно, вертер успешно
		(3, 'name_2', 'C2_SimpleBashUtils', '2023-02-01'), -- пир фэйл
		(4, 'name_2', 'C2_SimpleBashUtils', '2023-02-02'), -- пир успешно, вертер успешно
		(5, 'name_1', 'C3_s21_string+', '2023-03-01'), -- пир успешно, вертер успешно
		(6, 'name_1', 'C4_s21_math', '2023-03-10'), -- пир успешно, вертер успешно		
		(7, 'name_1', 'C5_s21_decimal', '2023-03-10'), -- пир успешно, вертер успешно
		(8, 'name_1', 'C6_s21_matrix', '2023-03-10'), -- пир успешно, вертер успешно
		(9, 'name_1', 'C7_SmartCalc_v1.0', '2023-04-10'), -- пир успешно, вертер успешно
		(10, 'name_1', 'C8_3DViewer_v1.0', '2023-05-10'), -- пир успешно, вертер успешно
		(11, 'name_1', 'DO1_Linux', '2023-05-10'), -- пир успешно, вертер успешно
		(12, 'name_1', 'SQL1_Bootcamp', '2023-05-10'); -- пир успешно, вертер успешно
/* P2P
Каждая P2P проверка состоит из 2-х записей в таблице:
первая имеет статус начало, вторая - успех или неуспех.
Каждая P2P проверка (т.е. обе записи, из которых она состоит)
ссылается на проверку в таблице Checks, к которой она относится.
*/
INSERT INTO p2p (id, "Check", checkingpeer, state, time) VALUES
		(1, 1, 'name_5', 'Start', '08:00:00'),
		(2, 1, 'name_5', 'Success', '08:20:00'), -- В вертер (id=2 будет фэйл)
		(3, 2, 'name_3', 'Start', '08:00:00'),
		(4, 2, 'name_3', 'Success', '08:20:00'), -- В вертер (id=4 будет успешно)
		(5, 3, 'name_4', 'Start', '08:00:00'),
		(6, 3, 'name_4', 'Failure', '08:20:00'),
		(7, 4, 'name_3', 'Start', '08:00:00'),
		(8, 4, 'name_3', 'Success', '08:20:00'), -- В вертер (id=6 будет успешно)
		(9, 5, 'name_3', 'Start', '08:00:00'),
		(10, 5, 'name_3', 'Success', '08:20:00'), -- В вертер (id=8 будет успешно)
		(11, 6, 'name_2', 'Start', '08:00:00'),
		(12, 6, 'name_2', 'Success', '08:20:00'), -- В вертер (id=10 будет успешно)
		(13, 7, 'name_3', 'Start', '08:00:00'),
		(14, 7, 'name_3', 'Success', '08:20:00'), -- В вертер (id=12 будет успешно)
		(15, 8, 'name_4', 'Start', '08:00:00'),
		(16, 8, 'name_4', 'Success', '08:20:00'), -- В вертер (id=14 будет успешно)
		(17, 9, 'name_5', 'Start', '08:00:00'),
		(18, 9, 'name_5', 'Success', '08:20:00'), -- В вертер (id=16 будет успешно)
		(19, 10, 'name_2', 'Start', '08:00:00'),
		(20, 10, 'name_2', 'Success', '08:20:00'), -- В вертер (id=18 будет успешно)
		(21, 11, 'name_3', 'Start', '08:00:00'),
		(22, 11, 'name_3', 'Success', '08:20:00'), -- В вертер (id=20 будет успешно)
		(23, 12, 'name_2', 'Start', '08:00:00'),
		(24, 12, 'name_2', 'Success', '08:20:00'); -- В вертер (id=22 будет успешно)

/* VERTER
Каждая проверка Verter'ом состоит из 2-х записей в таблице:
первая имеет статус начало, вторая - успех или неуспех.
Каждая проверка Verter'ом (т.е. обе записи, из которых она состоит)
ссылается на проверку в таблице Checks, к которой она относится.
Проверка Verter'ом может ссылаться только на те проверки в таблице Checks,
которые уже включают в себя успешную P2P проверку.
*/
INSERT INTO verter (id, "Check", state, "time") VALUES 
		(1, 1, 'Start', '08:20:00'),
		(2, 1, 'Failure', '08:21:00'),
		(3, 2, 'Start', '08:20:00'),
		(4, 2, 'Success', '08:21:00'),
		(5, 4, 'Start', '08:20:00'),
		(6, 4, 'Success', '08:21:00'),
		(7, 5, 'Start', '08:20:00'),
		(8, 5, 'Success', '08:21:00'),
		(9, 6, 'Start', '08:20:00'),
		(10, 6, 'Success', '08:21:00'),
		(11, 7, 'Start', '08:20:00'),
		(12, 7, 'Success', '08:21:00'),
		(13, 8, 'Start', '08:20:00'),
		(14, 8, 'Success', '08:21:00'),
		(15, 9, 'Start', '08:20:00'),
		(16, 9, 'Success', '08:21:00'),
		(17, 10, 'Start', '08:20:00'),
		(18, 10, 'Success', '08:21:00'),
		(19, 11, 'Start', '08:20:00'),
		(20, 11, 'Success', '08:21:00'),
		(21, 12, 'Start', '08:20:00'),
		(22, 12, 'Success', '08:21:00');

/* TRANSFEREDPOINTS
 При каждой P2P проверке проверяемый пир передаёт один пир поинт проверяющему.
Эта таблица содержит все пары проверяемый-проверяющий и кол-во переданных
пир поинтов, то есть, другими словами, количество P2P проверок указанного
проверяемого пира, данным проверяющим.
 * */
-- временную таблицу создаем
CREATE TEMP TABLE tmp (Checkingpeer varchar , checkedpeer varchar , PointsAmount int);
--вставляем туда вычесленные данные без ID
INSERT INTO tmp(
	SELECT checkingpeer, Peer, count(*) from P2P
	JOIN Checks ON Checks.ID = P2P."Check"
	WHERE State != 'Start'
	GROUP BY 1,2
);
ALTER TABLE tmp  ADD COLUMN id serial; -- вставка колонки с числами от 1
-- вставляем непосредственно данные
INSERT INTO transferredpoints (id, checkingpeer, checkedpeer, pointsamount)
	(SELECT id, checkingpeer, checkedpeer, pointsamount FROM tmp);
DROP TABLE tmp;

/* FRIENDS
Дружба взаимная, т.е. первый пир является другом второго,а второй - другом первого.
 * */
INSERT INTO Friends (ID, Peer1, Peer2)
VALUES (1, 'name_1', 'name_2'),
       (2, 'name_2', 'name_3'),
       (3, 'name_3', 'name_4'),
       (4, 'name_4', 'name_5'),
       (5, 'name_5', 'name_1');
       
/* RECOMMENADIONS
Каждому может понравиться, как проходила P2P проверка у того или итого пира.
Пир, указанный в поле Peer, рекомендует проходить P2P проверку у пира
из поля RecomendedPeer. Каждый пир может рекомендовать как ни одного,
так и сразу несколько проверяющих.
 * */
INSERT INTO recommendations  (id, peer, recommendedpeer)
VALUES (1, 'name_1', 'name_5'),
       (2, 'name_1', 'name_3'),
       (3, 'name_1', 'name_2'),
       (4, 'name_2', 'name_3'),
       (5, 'name_2', 'name_4');
       
/* XP
За каждую успешную проверку пир, выполнивший задание, получает какое-то количество
XP, отображаемое в этой таблице. Количество XP не может превышать
максимальное доступное для проверяемой задачи.
Первое поле этой таблицы может ссылаться только на успешные проверки.
 * */
INSERT INTO XP (id, "Check", xpamount) VALUES
		(1, 2, 210),
		(2, 4, 230),
		(3, 5, 490),
		(4, 6, 300),
		(5, 7, 301),
		(6, 8, 161),
		(7, 9, 490),
		(8, 10, 749),
		(9, 11, 270),
		(10, 12, 1450);

/* TIMETRACKING
Данная таблица содержит информация о посещениях пирами кампуса.
Когда пир входит в кампус, в таблицу добавляется запись с состоянием 1,
когда покидает - с состоянием 2.
 * */
INSERT INTO timetracking (id, peer, date, time, state) VALUES
		(1, 'name_1', '2023-01-01', '07:30:00', 1),
		(2, 'name_1', '2023-01-01', '17:30:00', 2),
		(3, 'name_2', '2023-02-01', '07:30:00', 1),
		(4, 'name_2', '2023-02-01', '17:30:00', 2),
		(5, 'name_2', '2023-02-03', '17:30:00', 1),
		(6, 'name_2', '2023-02-03', '20:34:17', 2),
		(7, 'name_5', '2023-02-05', '06:30:00', 1),
		(8, 'name_5', '2023-02-05', '12:34:17', 2),
		(9, 'name_5', '2023-02-05', '13:30:00', 1),
		(10, 'name_5', '2023-02-05', '19:34:17', 2),
		(11, 'name_3', '2023-03-08', '10:07:00', 1),
		(12, 'name_3', '2023-03-08', '19:34:17', 2);



--ЭКСПОРТ и ИМПОРТ ТАБЛИЦ
--!!! ВАЖНО!!! в названии пути и файла НЕ должно быть киррилицы иначе возможна ошибка "No such file or directory"
--Процедура экспорта(название таблицы, полный путь с названием конечного файла, разделитель)
CREATE OR REPLACE PROCEDURE export(tablename varchar, path text, separator char) AS $$
    BEGIN
	    -- EXECUTE - динамическое формирование команды внутри функции
	    -- FORMAT - Форматирует аргумент в соответствии со строкой формата. Эта функция работает подобно sprintf в языке C.
        EXECUTE format(
        		'COPY %s TO ''%s'' DELIMITER ''%s'' CSV HEADER;',
            	tablename,
            	path,
            	separator
     	);
    END;
$$ LANGUAGE plpgsql;

--Процедура импорта(название таблицы какое будет, поный путь названия CSV файла, разделитель)
CREATE OR REPLACE PROCEDURE import(tablename varchar, path text, separator char) AS $$
    BEGIN
        EXECUTE format(
        	'COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER;',
            tablename,
           	path,
          	separator
      	);
    END;
$$ LANGUAGE plpgsql;

--пример экспорта таблицы в CSV Файл:
--CALL export('peers', 'C:\Nikolay\CSV\peers.csv', ',');