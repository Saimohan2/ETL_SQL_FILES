use warehouse compute_wh;
create database mydata;
create schema mydata.rawdata;
create schema mydata.staging;
create schema mydata.transformed;

select *
from mydata.rawdata.working_data;

use database netflix_db;

select * from dbt_smohan.stg_working_data;

select * from dbt_smohan.daywiseanalysis;

use database mydata;
use schema rawdata;
use warehouse compute_wh;

---Create a target table to load data

create or replace table mailed_data(
account_name string,
first_name string,
last_name string,
designation string,
email_id string,
practice string,
initial string,
initial_status string,
fup1 string,
fup1_status string,
fup2 string,
fup2_status string,
comments string,
created_at timestamp default current_timestamp,
updated_at timestamp
);

select * from mydata.rawdata.mailed_data;

---create a file format

create or replace file format csv_format
type = CSV
field_optionally_enclosed_by = '"'
skip_header=1;

/*create a stage, after creating a IAM user that can access the stage,
credentials should be created as well. There should be a SnowflakeReadpolicy
that should be tagged to the user.*/

create or replace stage s3_mailed_data
url = 's3://mails-data-bucket/'
credentials = (aws_key_id = 'xxx'
                aws_secret_key = 'xxx')
file_format = csv_format;

--- this lists all the files present in the folder mentioned in stage

list @s3_mailed_data;

--- copies the data present in the mentioned file into the table created

copy into mailed_data(account_name,
    first_name,
    last_name,
    designation,
    email_id,
    practice,
    initial,
    initial_status,
    fup1,
    fup1_status,
    fup2,
    fup2_status,
    comments
)
from @s3_mailed_data/mailing_data.csv
file_format=(format_name=csv_format)
on_error='continue';

--- below just played around with the data

select * from mydata.rawdata.mailed_data;

select * from netflix_db.dbt_smohan.s3load;

select * from netflix_db.dbt_smohan.response_analysis;

select day, count(*) as appearances
from(select * from netflix_db.dbt_smohan.response_analysis)t
group by day
order by appearances desc
limit 2;

select * from mydata.rawdata.historical_mails_table;

select comments, count(*) as cnt, 
concat(round(100.0*count(*)/(select count(*) from mydata.rawdata.historical_transformed),2),'','%') as perc
from mydata.rawdata.historical_transformed
group by comments;

update mydata.rawdata.historical_transformed
set comments='Positive'
where initial_status like 'Po%' or
    fup1_status like 'Po%' or
    fup2_status like 'Po%';

select distinct comments from mydata.rawdata.historical_transformed; 

select mn, count(*) as num
from(select trim(concat(first_name,' ',coalesce(last_name,''))) as contact_name,
    title, email_id, month(initial) as mn, comments
from mydata.rawdata.historical_transformed
where comments not in ('DELIVERED', 'Bounced'))t
group by mn
order by num desc;

select day, count(*) as responses
from(select dayname(initial) as day, initial_status as response
from mydata.rawdata.historical_transformed
where initial_status not like 'NO%' and comments not like 'Bo%'
union all
select dayname(fup1), fup1_status
from mydata.rawdata.historical_transformed
where fup1_status not like 'NO%' and comments not like 'Bo%'
union all
select dayname(fup2), fup2_status
from mydata.rawdata.historical_transformed
where fup2_status not like 'NO%' and comments not like 'Bo%')t
group by day
order by responses desc;