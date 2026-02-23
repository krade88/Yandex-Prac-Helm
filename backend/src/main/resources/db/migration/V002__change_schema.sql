-- Добавление первичного ключа по полю id в таблицу product
ALTER TABLE product
    ADD PRIMARY KEY (id);

-- Добавление первичного ключа по полю id в таблицу orders
ALTER TABLE orders
    ADD PRIMARY KEY (id);

-- Добавление нового столбца price типа DOUBLE PRECISION в таблицу product
ALTER TABLE product
    ADD price DOUBLE PRECISION;

-- Добавление нового столбца date_created типа date в таблицу orders
ALTER TABLE orders
    ADD date_created date;

-- Удаление таблицы product_info, если она больше не используется
DROP TABLE product_info;

-- Удаление таблицы orders_date, если она больше не используется
DROP TABLE orders_date;

-- Добавление внешнего ключа для связи order_id из таблицы order_product с таблицей orders по полю id
ALTER TABLE order_product
    ADD CONSTRAINT fk_orders_id FOREIGN KEY (order_id) REFERENCES orders (id);

-- Добавление внешнего ключа для связи product_id из таблицы order_product с таблицей product по полю id
ALTER TABLE order_product
    ADD CONSTRAINT fk_product_id FOREIGN KEY (product_id) REFERENCES product (id);
