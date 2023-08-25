-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных, уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.

CREATE OR REPLACE PROCEDURE proc_remove_tables_by_name() 
AS $$
DECLARE
   table_rec record;
BEGIN
   for table_rec in (SELECT tablename AS tname
                    FROM pg_catalog.pg_tables
                    WHERE schemaname != 'pg_catalog'
                    AND schemaname != 'information_schema'
                    AND tablename ~ '^TableName')
   loop
     execute 'drop table "'||table_rec.tname||'" cascade';
   end loop;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_remove_tables_by_name();
-- END;