--Задание 1 Выведите название самолетов, которые имеют менее 50 посадочных мест?

select a.model 
from (select aircraft_code ,count(seat_no)  from seats s group by aircraft_code having count(seat_no) < 50) t
join aircrafts a on a.aircraft_code = t.aircraft_code

--Задание 2 Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

select *,
lag (summ) over () "Прошлый месяц",
round((((summ - lag(summ) over ()) / lag(summ) over ()) * 100),2) "Изменение относ. пред месяца, %"
from 
(select date_trunc('month', book_date)::date months,
sum(total_amount) summ
from bookings b group by date_trunc('month', book_date) order by date_trunc('month', book_date)) t 

--Задание 3 Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.

select a.model 
from 
(select aircraft_code , array_agg(distinct fare_conditions)
from seats s
group by aircraft_code 
having 'Business' != all(array_agg(distinct fare_conditions::text))) t 
join aircrafts a on a.aircraft_code = t.aircraft_code

--Задание 4 Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, 
           --учитывая только те самолеты, которые летали пустыми и только те дни, 
           --где из одного аэропорта таких самолетов вылетало более одного.
		   --В результате должны быть код аэропорта, дата, количество пустых мест и накопительный итог.

select t.departure_airport,t.actual_departure,t.actual_arrival,mesta as mesta_pustie, 
sum(mesta) over (partition by t.actual_departure::date, t.departure_airport order by t.actual_departure) nakopitelnaya
from
(with cte as (select aircraft_code , count(seat_no) mesta from seats s group by aircraft_code)
select * from
(select *
from
(select *, count(t.flight_id) over (partition by t.actual_departure::date, t.departure_airport) res
from
(select * from boarding_passes bp 
full outer join flights f using (flight_id) where (f.status = 'Arrived' or f.status = 'Departed') and seat_no is null order by f.actual_departure, f.departure_airport) t) t -- пустые рейсы
where res > 1) t
join cte on cte.aircraft_code = t.aircraft_code order by t.actual_departure::date, t.departure_airport ) t

-- --Задание 5 Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов. 
--Выведите в результат названия аэропортов и процентное отношение.
--Решение должно быть через оконную функцию.

select "Аэропорт вылета", a.airport_name "Аэропорт прилета", "Процент"
from
(select a.airport_name "Аэропорт вылета", t.procent "Процент", arrival_airport
from 
(select departure_airport , arrival_airport ,
((count(*) over (partition by departure_airport, arrival_airport))::numeric  / (count(*) over())) * 100 procent
from flights f
group by departure_airport , arrival_airport) t 
join airports a on a.airport_code = t.departure_airport) t
join airports a on a.airport_code = t.arrival_airport

--Задание 6 Выведите количество пассажиров по каждому коду сотового оператора,
-- если учесть, что код оператора - это три символа после +7

select kod, count(kod) "Количество"
from
(select *, substring(((contact_data->>'phone')::text) from 3 for 3) kod
from tickets t) t
group by kod

--Задание 7 Классифицируйте финансовые обороты (сумма стоимости билетов) по маршрутам:
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом полученном классе.

select klass, count(marshrut)
from
(select *, case when summ < 50000000 then 'low'
               when summ >= 50000000 and summ < 150000000 then 'middle'
               when summ >= 150000000 then 'high'
           end klass
from 
(select concat_ws(' ', f.departure_airport, f.arrival_airport) marshrut, sum(summ) summ 
from
(select flight_id, sum(amount) summ , count(amount) kolichestvo from  ticket_flights tf group by flight_id) t 
join flights f on f.flight_id = t.flight_id
group by f.departure_airport, f.arrival_airport) t ) t
group by klass

--Задание 8 Вычислите медиану стоимости билетов,
--медиану размера бронирования и отношение медианы бронирования к медиане стоимости билетов, округленной до сотых.

select (select Percentile_Disc (0.5) within group (order by total_amount)
from bookings b) "Бронирование",
(select Percentile_Disc (0.5) within group (order by amount) from ticket_flights tf  ) "Билеты",
round(((select Percentile_Disc (0.5) within group (order by total_amount)
from bookings b) / (select Percentile_Disc (0.5) within group (order by amount) from ticket_flights tf )),2) "Отношение"

--Задание 9 Найдите значение минимальной стоимости полета 1 км для пассажиров. 
--То есть нужно найти расстояние между аэропортами и с учетом стоимости билетов получить искомый результат.

create extension cube
create extension earthdistance				
				
select min(rubles) from
	(select *, earth_distance(ll_to_earth ( lat_dep , long_dep ), ll_to_earth ( lat_arr , long_arr  )) / 1000 kilometri,
	summ / (earth_distance(ll_to_earth ( lat_dep , long_dep ), ll_to_earth ( lat_arr , long_arr  )) / 1000) rubles
	from
		(select summ, long_dep, lat_dep, a.longitude long_arr, a.latitude lat_arr
		from
			(select t.amount summ, a.longitude long_dep, a.latitude lat_dep, t.arrival_airport
			from
				(select f.flight_id, f.departure_airport , f.arrival_airport, tf.amount  from ticket_flights tf
				join flights f on f.flight_id = tf.flight_id group by f.flight_id, tf.amount) t  
			join airports a on a.airport_code = t.departure_airport) t
		join airports a on a.airport_code = t.arrival_airport) t) t
