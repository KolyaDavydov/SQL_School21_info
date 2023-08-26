-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных, уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.

CREATE OR REPLACE PROCEDURE proc_remove_tables_by_name() 
AS $$
DECLARE
   table_rec record;
BEGIN
   FOR table_rec IN (SELECT tablename AS tname
                    FROM pg_catalog.pg_tables
                    WHERE schemaname != 'pg_catalog'
                    AND schemaname != 'information_schema'
                    AND tablename ~ '^TableName')
   LOOP
     EXECUTE 'DROP TABLE "' || table_rec.tname || '" CASCADE';
   END LOOP;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_remove_tables_by_name();
-- END;

-- 2) Создать хранимую процедуру с выходным параметром, которая выводит список имен и параметров всех скалярных SQL функций пользователя в текущей базе данных. 
-- Имена функций без параметров не выводить. Имена и список параметров должны выводиться в одну строку. Выходной параметр возвращает количество найденных функций.

CREATE OR REPLACE PROCEDURE proc_search_func_with_param(res OUT TEXT, func_count OUT INTEGER) 
AS $$
DECLARE
    table_rec record;
BEGIN
res := '';
func_count := 0;
FOR table_rec IN (SELECT
                  proname || ' ' || concat_ws(',',proargnames) AS Name
                  FROM pg_catalog.pg_proc pr
                  JOIN pg_catalog.pg_namespace ns ON ns.oid = pr.pronamespace
                  WHERE prokind = 'f'
                  AND nspname != 'pg_catalog'
                  AND nspname != 'information_schema'
                  AND proargnames IS NOT NULL)
LOOP
     res := (res || table_rec.name || ' ');
     func_count = func_count+1;
   END LOOP;
RETURN;
END;
$$ LANGUAGE plpgsql;

-- CALL proc_search_func_with_param('',0);

-- 3) Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных. 
-- Выходной параметр возвращает количество уничтоженных триггеров.

CREATE OR REPLACE PROCEDURE proc_remove_all_triggers(OUT trigger_count INTEGER) 
AS $$
DECLARE
    table_rec record;
BEGIN
   FOR table_rec IN (SELECT  event_object_table AS table_name ,trigger_name         
                    FROM information_schema.triggers  
                    GROUP BY table_name , trigger_name 
                    ORDER BY table_name ,trigger_name)
   LOOP
     EXECUTE 'DROP TRIGGER "' || table_rec.trigger_name ||'" ON "' || table_rec.table_name || '" CASCADE;';
     trigger_count = trigger_count+1;
   END LOOP;
   RETURN;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_remove_all_triggers(0);
-- END;

-- 4) Создать хранимую процедуру с входным параметром, которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций), 
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.
-- TODO проверить какая-то фигня с выводом 

CREATE OR REPLACE PROCEDURE proc_search_string_in_proc(needle IN VARCHAR, res REFCURSOR) 
AS $$
BEGIN
    OPEN res FOR
            SELECT
            proname AS Name,
            CASE prokind WHEN 'p' THEN 'Procedure' 
            WHEN 'f' THEN 'Function' ELSE NULL END
            AS Description
            FROM pg_catalog.pg_proc pr
            JOIN pg_catalog.pg_namespace ns ON ns.oid = pr.pronamespace
            WHERE prosrc ilike '%' || needle || '%'
            AND nspname != 'pg_catalog'
            AND nspname != 'information_schema';
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_search_string_in_proc('drop', 'res');
-- FETCH ALL FROM "res";
-- END;
