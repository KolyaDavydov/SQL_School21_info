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
     execute 'DROP TABLE "' || table_rec.tname || '" CASCADE';
   end loop;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_remove_tables_by_name();
-- END;

-- 2) Создать хранимую процедуру с выходным параметром, которая выводит список имен и параметров всех скалярных SQL функций пользователя в текущей базе данных. 
-- Имена функций без параметров не выводить. Имена и список параметров должны выводиться в одну строку. Выходной параметр возвращает количество найденных функций.

-- 3) Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных. 
-- Выходной параметр возвращает количество уничтоженных триггеров.
CREATE OR REPLACE PROCEDURE proc_remove_all_triggers(trg_count INTEGER) 
AS $$
DECLARE
    trigger_count INTEGER;
    table_rec record;
BEGIN
   for table_rec in (SELECT  event_object_table AS table_name ,trigger_name         
                    FROM information_schema.triggers  
                    GROUP BY table_name , trigger_name 
                    ORDER BY table_name ,trigger_name)
   loop
     execute 'DROP TRIGGER "' || table_rec.trigger_name ||'" ON "' || table_rec.table_name || '" CASCADE;'; 
   end loop;
   SELECT @trigger_count = COUNT(trigger_name) FROM table_rec;
END;
$$ LANGUAGE plpgsql;

-- BEGIN; 
-- CALL proc_remove_all_triggers();
-- END;
-- 4) Создать хранимую процедуру с входным параметром, которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций), 
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.