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
        INSERT INTO P2P VALUES (
            (SELECT count(*) + 1 FROM P2P),
            (SELECT "Check" FROM P2P WHERE CheckingPeer = checker AND State = 'Start'),
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
        SELECT "Check", max(P2P.time)
        FROM P2P
        JOIN Checks AS c
            ON  c.Task = task_name
            AND c.Peer = checking
        WHERE P2P.state = 'Success'
        GROUP BY "Check"
    )
    INSERT INTO Verter VALUES (
        (SELECT count(*) + 1 FROM Verter),
        (SELECT "Check" FROM last_successfull_check),
        verter_status,
        time
    );
END;
$$ LANGUAGE plpgsql;
