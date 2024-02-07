-- В скольких торговых точках продаются товары, производимые участником оборота. Вычислить среднемесячный показатель за плавающий год для прошлого месяца
-- ClickHouse

WITH prod_list AS ( -- опраделяем список товаров с производством РФ/импортом ЛП
    SELECT DISTINCT gtin, --Global Trade Item Number (GTIN) — международный 14-значный номер штрих-кода. Общий для одинаковых товаров
            inn_prod -- инн производителя        
    FROM aic -- агрегат с информацией о вводе товаров в оборот
        LEFT JOIN dict.docs_in_circulation_type d ON aic.doc_type = d.doc_type -- справочник типов ввода в оборот по типу документа
    where   cnt > 0 --кол-во введенных в оборот товаров
        AND (inn_prod = '{{ ИНН }}' OR '{{ ИНН }}' = 'All') -- фильтр для поиска по всем (all) или конкретному ИНН
        AND date BETWEEN date_add(MONTH, -12, toStartOfMonth(now())) AND date_add(DAY, -1, toStartOfMonth(now())) 
        and d.type = 'РФ'-- тип ввода в оборот       
)
, month_sp AS ( -- подсчет кол-ва точек, в которых осуществлялась продажа товаров, по месяцам
    SELECT l.inn_prod AS inn_prod, 
        toStartOfMonth(date) AS month,
        count(DISTINCT salespoint_id) AS sp_cnt
    FROM prod_list AS l 
        LEFT JOIN ( -- выгрузка всех продаж за интересующий период
                    SELECT DISTINCT inn_prod,  gtin, date, salespoint_id -- id точки продажи
                    FROM  sales -- все продажи 
                    WHERE  date BETWEEN date_add(MONTH, -12, toStartOfMonth(today())) AND date_add(DAY, -1, toStartOfMonth(today()))
                        and date >= toDate(dictGetDateTime('ch_dict.start_product_group', 'start_date', product_group)) -- справочник дат старта обязательной маркировки товарных групп
                        and cnt > 0 --кол-во проданных товаров
                        AND (inn_prod = '{{ ИНН }}' OR '{{ ИНН }}' = 'All')
                    ) AS s ON s.inn_prod = l.inn_prod AND s.gtin = l.gtin
    GROUP BY l.inn_prod, month
)

, total AS (-- считаем среднемесячное кол-во точек продаж, в которых продавались товары производителя
    SELECT inn_prod, 
         SUM(sp_cnt)/AGE('month', MIN(month), date_add(MONTH, 1, MAX(month))) AS sp_cnt --считается среднее за кол-во месяцев между первой и последней зафиксированной продажей
        -- чтобы в случаях, если участник только начал свою деятельность или, наоборот, несколько месяцев назад закончил - среднее считалось не за все 12 месяцев,
        -- а только за тот период, когда деятельость осуществлялась
    FROM month_sp
    GROUP BY inn_prod
)

SELECT inn_prod, 
    CASE -- разбиение производителей по сегментам. Сегменты были определены после анализа распределения производителей по кол-ву точек, в которых продается их продукция
        WHEN round(sp_cnt)> 60 THEN 'более 60 торговых точек'
        WHEN round(sp_cnt) > 14 THEN '15-60 торговых точек'
        WHEN round(sp_cnt) > 2 THEN '3-14 торговых точек'
        WHEN sp_cnt > 0 THEN '1-2 торговые точки'
        WHEN sp_cnt = 0 THEN 'не продается в РФ' -- может производить товар только для экспорта
    END AS segment,
    sp_cnt -- расчитанное среднемесячное кол-во точек, в которых продаются товары производителя
FROM total
