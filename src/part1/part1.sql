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
Чтобы получить доступ к заданию, нужно выполнить задание,
являющееся его условием входа. Для упрощения будем считать,
что у каждого задания всего одно условие входа.
В таблице должно быть одно задание, у которого нет условия входа
(т.е. поле ParentTask равно null).
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
Описывает проверку задания в целом. Проверка обязательно включает в себя этап P2P и,
возможно, этап Verter. Для упрощения будем считать, что пир ту пир и автотесты,
относящиеся к одной проверке, всегда происходят в один день.
Проверка считается успешной, если соответствующий P2P этап успешен,
а этап Verter успешен, либо отсутствует. Проверка считается неуспешной,
хоть один из этапов неуспешен. То есть проверки, в которых ещё не завершился этап P2P,
или этап P2P успешен, но ещё не завершился этап Verter,
не относятся ни к успешным, ни к неуспешным.
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
Каждая P2P проверка состоит из 2-х записей в таблице:
первая имеет статус начало, вторая - успех или неуспех.
Каждая P2P проверка (т.е. обе записи, из которых она состоит)
ссылается на проверку в таблице Checks, к которой она относится.
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
Каждая проверка Verter'ом состоит из 2-х записей в таблице:
первая имеет статус начало, вторая - успех или неуспех.
Каждая проверка Verter'ом (т.е. обе записи, из которых она состоит)
ссылается на проверку в таблице Checks, к которой она относится.
Проверка Verter'ом может ссылаться только на те проверки в таблице Checks,
которые уже включают в себя успешную P2P проверку.
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
При каждой P2P проверке проверяемый пир передаёт один пир поинт проверяющему.
Эта таблица содержит все пары проверяемый-проверяющий и кол-во переданных
пир поинтов, то есть, другими словами, количество P2P проверок указанного
проверяемого пира, данным проверяющим.
 * */
CREATE TABLE IF NOT EXISTS TransferredPoints(
	ID			integer	PRIMARY KEY,
	CheckingPeer varchar,
	CheckedPeer	varchar,
	PointsAmount integer,
	
    FOREIGN KEY (CheckingPeer)	REFERENCES Peers (Nickname),
    FOREIGN KEY (CheckedPeer)	REFERENCES Peers (Nickname)
);

/*
	Таблица Friends
		- ID
		- Ник первого пира
		- Ник второго пира
Дружба взаимная, т.е. первый пир является другом второго,а второй -- другом первого.
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
Каждому может понравиться, как проходила P2P проверка у того или итого пира.
Пир, указанный в поле Peer, рекомендует проходить P2P проверку у пира
из поля RecomendedPeer. Каждый пир может рекомендовать как ни одного,
так и сразу несколько проверяющих.
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
За каждую успешную проверку пир, выполнивший задание, получает какое-то количество
XP, отображаемое в этой таблице. Количество XP не может превышать
максимальное доступное для проверяемой задачи.
Первое поле этой таблицы может ссылаться только на успешные проверки.
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
Данная таблица содержит информация о посещениях пирами кампуса.
Когда пир входит в кампус, в таблицу добавляется запись с состоянием 1,
когда покидает - с состоянием 2.
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