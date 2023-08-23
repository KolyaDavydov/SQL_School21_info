CREATE OR REPLACE PROCEDURE add_p2p_check(
    IN checking    VARCHAR,
    IN checker     VARCHAR,
    IN task_name   VARCHAR,
    IN p2p_status  CHECK_STATUS,
    IN "time"      TIME
)
AS $$
BEGIN
    IF (p2p_status = 'Start') THEN
        INSERT INTO Checks VALUES (
            (SELECT count(*) + 1 FROM Checks),
            checking,
            task_name,
            now()
        );

        INSERT INTO P2P VALUES (
            (SELECT count(*) + 1 FROM P2P),
            (SELECT max(Checks.id) FROM Checks WHERE Peer = checking AND Task = task_name),
            checker,
            p2p_status,
            time
        );
    ELSE
        WITH last_started_check AS (
            SELECT c.id AS check_id, max(P2P.time)
            FROM P2P
            JOIN Checks AS c
                ON  c.Task = task_name
                AND c.Peer = checking
            WHERE P2P.state = 'Start'
            GROUP BY check_id
            ORDER BY 1 DESC
            LIMIT 1
        )
        INSERT INTO P2P VALUES (
            (SELECT count(*) + 1 FROM P2P),
            (SELECT lsc.check_id FROM last_started_check AS lsc),
            checker,
            p2p_status,
            time
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_verter_check(
    IN checking       VARCHAR,
    IN task_name      VARCHAR,
    IN verter_status  CHECK_STATUS,
    IN "time"         TIME
)
AS $$
BEGIN
    WITH last_successfull_check AS (
        SELECT "Check" AS check_id, max(P2P.time)
        FROM P2P
        JOIN Checks AS c
            ON  p2p."Check" = c.id
            AND c.Peer = checking
        WHERE P2P.state = 'Success' AND c.Task = task_name
        GROUP BY check_id
        ORDER BY 1 DESC, 2 DESC
        LIMIT 1
    )
    INSERT INTO Verter VALUES (
        (SELECT count(*) + 1 FROM Verter),
        (SELECT lsc.check_id FROM last_successfull_check AS lsc),
        verter_status,
        time
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fnc_trg_transfer_peer_point()
RETURNS TRIGGER AS $trg_transfer_peer_point$
    BEGIN 
        WITH peer AS (
            SELECT Peer, max(P2P.time)
            FROM Checks
            JOIN P2P
            ON NEW."Check" = Checks.id
            GROUP BY Checks.id
            ORDER BY 1 DESC
            LIMIT 1
        )
        UPDATE TransferredPoints
        SET PointsAmount = PointsAmount + 1
        WHERE CheckedPeer = NEW.CheckingPeer AND CheckingPeer = (SELECT Peer FROM peer);
        RETURN NULL;
    END;
$trg_transfer_peer_point$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transfer_peer_point
AFTER INSERT ON p2p
FOR EACH ROW
WHEN (NEW.State = 'Start')
EXECUTE FUNCTION fnc_trg_transfer_peer_point();
