
-- Problem 19
select top 3
	ah.*
	,gh.*
	,c.*
	,h.*
	,hs.*
	from state s
join all_hospitals ah on ah.State_UT = s.State_UT
join government_hospital gh on gh.State_UT = s.State_UT
join census_2011 c on c.State_UT = s.State_UT
join district d on c.District = d.District
join housing h on h.District = d.District
join housing_with_state hs on hs.District = d.District;

-- Problem 21
drop procedure get_population_district;
create procedure get_population_district(@dist_name varchar(50))
as
	select Population
	from census_2011
	where District= @dist_name
;
exec get_population_district 'South Andaman';

drop procedure get_population;
create procedure get_population(@state_name varchar(50))
as
	select sum(Population) as Population
	from census_2011
	where State_UT= @state_name
;
exec get_population 'Andaman and Nicobar Islands';

drop procedure senior_citizen_population;
create procedure senior_citizen_population(@state_name varchar(50))
as
	select sum(Senior_Citizen) as Population
	from census_2011
	where State_UT= @state_name
;
exec senior_citizen_population 'Andaman and Nicobar Islands';

drop procedure get_hospital_beds;
create procedure get_hospital_beds(@state_name varchar(50))
as
	select sum(HospitalBeds) as HospitalBed
	from all_hospitals
	where State_UT= @state_name
;
exec get_hospital_beds 'Andaman and Nicobar Islands';

drop procedure get_govt_hospital_beds;
create procedure get_govt_hospital_beds(@state_name varchar(50))
as
	select sum(Rural_Government_Beds+Urban_Government_Beds) as HospitalBed
	from government_hospital
	where State_UT= @state_name
;
exec get_govt_hospital_beds 'Andaman and Nicobar Islands';

drop procedure beds_per_lakh;
create procedure beds_per_lakh(@state_name varchar(50))
as
	select max(ah.HospitalBeds)*100000/sum(c.Population) as HospitalBed
	from all_hospitals ah
	join census_2011 c on c.State_UT = ah.State_UT
	where c.State_UT=@state_name
;
exec beds_per_lakh 'Andaman and Nicobar Islands';

drop procedure govt_beds_per_lakh;
create procedure govt_beds_per_lakh(@state_name varchar(50))
as
	select max(gh.Urban_Government_Beds + gh.Rural_Government_Beds)*100000/sum(c.Population) as HospitalBed
	from government_hospital gh
	join census_2011 c on c.State_UT = gh.State_UT
	where c.State_UT=@state_name
;
exec govt_beds_per_lakh 'Andaman and Nicobar Islands';

-- Problem 23
-- Sorted Data by no_of_no_toilet_percent so that secretary can focus on them first
drop procedure district_report_toilet;
create procedure district_report_toilet
as
	select 
		c.District
		,c.Population
		,c.Households
		,c.Households - (h.Households_Rural_Toilet_Premise+h.Households_Urban_Toilet_Premise) as no_of_no_toilet
		,1 - ( (h.Households_Rural_Toilet_Premise+h.Households_Urban_Toilet_Premise)/c.Households ) as no_of_no_toilet_percent
	from census_2011 c
	left join housing_with_state h on h.District=c.District and h.State_UT=c.State_UT
	order by no_of_no_toilet_percent
;
exec district_report_toilet;

-- Problem 24
drop procedure district_report_liv_dilap;
create procedure district_report_liv_dilap
as
	select 
		c.District
		,c.Population
		,(h.Households_Rural_Livable+h.Households_Urban_Livable)*1000/c.Population as no_liv_per1000
		,(h.Households_Rural_Dilapidated+h.Households_Urban_Dilapidated)*1000/c.Population as no_dilap_per1000
	from census_2011 c
	join housing_with_state h on h.District=c.District and h.State_UT=c.State_UT
;
exec district_report_liv_dilap;

-- Problem 25
select 
	c.State_UT
	,max(h.HospitalBeds) as HospitalBed
	,max(gh.Rural_Government_Beds)*100000.0/sum(c.Population) as gov_rural_per_lakh
	,max(gh.Urban_Government_Beds)*100000.0/sum(c.Population) as gov_urban_per_lakh
	,(max(gh.Rural_Government_Beds)*100000.0/sum(c.Population)) - (max(gh.Urban_Government_Beds)*100000.0/sum(c.Population)) as diff_rural_urban
from census_2011 c
join all_hospitals h on h.State_UT=c.State_UT
join government_hospital gh on gh.State_UT=c.State_UT
group by c.State_UT

-- Problem 26
-- drop table hospital_log;
create table hospital_log(
	state varchar(50),
	status varchar(20),
	is_govt bit,
	dt_updated datetime
);

-- drop trigger all_hospital_log_tgr;
create trigger all_hospital_log_tgr
on dbo.all_hospitals
for insert, delete
as
begin
	if exists (select 0 from inserted)
		begin
			insert into hospital_log(
				state,
				status,
				is_govt,
				dt_updated
			)
			select
				State_UT
				,'Inserted'
				,0
				,getdate()
			from inserted
		end
	 else
		begin
			insert into hospital_log(
				state,
				status,
				is_govt,
				dt_updated 
			)
			select
				State_UT
				,'Deleted'
				,0
				,getdate()
			from deleted
		end
end

-- drop trigger govt_hospital_log_tgr;
create trigger govt_hospital_log_tgr
on dbo.government_hospital
for insert, delete
as
begin
	if exists (select 0 from inserted)
		begin
			insert into hospital_log(
				state,
				status,
				is_govt,
				dt_updated 
			)
			select
				State_UT
				,'Inserted'
				,1
				,getdate()
			from inserted
		end
	else
		begin
			insert into hospital_log(
				state,
				status,
				is_govt,
				dt_updated 
			)
			select
				State_UT
				,'Deleted'
				,1
				,getdate()
			from deleted
		end
end

-- Problem 27
-- drop table hospital_bed_log
create table hospital_bed_log(
	state varchar(50),
	is_govt bit,
	region varchar(20),
	old_value decimal(10, 2),
	new_value decimal(10, 2),
	dt_updated datetime
);

-- drop trigger all_hospital_beg_log_tgr;
create trigger all_hospital_beg_log_tgr
on dbo.all_hospitals
for update
as
begin
	if update (HospitalBeds)
		begin
			insert into hospital_bed_log(
				state,
				is_govt,
				region,
				old_value,
				new_value,
				dt_updated
			)
			select
				i.State_UT
				,0
				,NULL
				,d.HospitalBeds
				,i.HospitalBeds
				,getdate()
			from inserted i 
			join deleted d on i.State_UT = d.State_UT
			where i.HospitalBeds != d.HospitalBeds
		end
end

-- drop trigger govt_hospital_beg_log_tgr;
create trigger govt_hospital_beg_log_tgr
on dbo.government_hospital
for update
as
begin
	begin
	if update (Urban_Government_Beds)
		begin
			insert into hospital_bed_log(
				state,
				is_govt,
				region,
				old_value,
				new_value,
				dt_updated
			)
			select
				i.State_UT
				,1
				,'Urban'
				,d.Urban_Government_Beds
				,i.Urban_Government_Beds
				,getdate()
			from inserted i 
			join deleted d on i.State_UT = d.State_UT
			where i.Urban_Government_Beds != d.Urban_Government_Beds
		end
	end
	begin
	if update(Rural_Government_Beds)
		begin
			insert into hospital_bed_log(
				state,
				is_govt,
				region,
				old_value,
				new_value,
				dt_updated
			)
			select
				i.State_UT
				,1
				,'Rural'
				,d.Rural_Government_Beds
				,i.Rural_Government_Beds
				,getdate()
			from inserted i 
			join deleted d on i.State_UT = d.State_UT
			where i.Rural_Government_Beds != d.Rural_Government_Beds
		end
	end
end

