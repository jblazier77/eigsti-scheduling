-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_pricing_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_pricing_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_pricing_results,pg_temp.eigsti_pricing_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_pricing_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','quick-pm@example.invalid'),
('22222222-2222-4222-8222-222222222222','review-pm2@example.invalid'),
('33333333-3333-4333-8333-333333333333','quick-lead@example.invalid'),
('44444444-4444-4444-8444-444444444444','quick-other@example.invalid'),
('55555555-5555-4555-8555-555555555555','quick-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','quick-admin@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC PM2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Other lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true);
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_pricing_ids values('vendor_a',(public.save_subcontractor(null,'abcdefab-cdef-4abc-8abc-000000000001','{"name":"SYNTHETIC Vendor A","phone":"","email":"","trades":["framing"],"contact_types":["vendor","subcontractor"],"notes":"Fictional supplier"}')->>'id')::uuid),('vendor_b',(public.save_subcontractor(null,'abcdefab-cdef-4abc-8abc-000000000002','{"name":"SYNTHETIC Vendor B","phone":"","email":"","trades":[],"contact_types":["vendor"]}')->>'id')::uuid),('legacy',(public.save_subcontractor(null,'abcdefab-cdef-4abc-8abc-000000000003','{"name":"SYNTHETIC Legacy","phone":"","email":"","trades":[]}')->>'id')::uuid);
create function pg_temp.pricing_sheet(v uuid,r uuid,c text default 'Lumber',e date default (now() at time zone 'America/Chicago')::date) returns uuid language sql as $helper$select (public.begin_vendor_price_list(r,v,c,e,null,'Tax and freight extra','SYNTHETIC pricing.pdf','application/pdf',12)->>'id')::uuid;$helper$;
insert into pg_temp.eigsti_pricing_ids values('list_a',pg_temp.pricing_sheet((select id from pg_temp.eigsti_pricing_ids where label='vendor_a'),'abcdefab-cdef-4abc-8abc-000000000004')),('list_b',pg_temp.pricing_sheet((select id from pg_temp.eigsti_pricing_ids where label='vendor_b'),'abcdefab-cdef-4abc-8abc-000000000005')),('list_new',pg_temp.pricing_sheet((select id from pg_temp.eigsti_pricing_ids where label='vendor_a'),'abcdefab-cdef-4abc-8abc-000000000006')),('list_future',pg_temp.pricing_sheet((select id from pg_temp.eigsti_pricing_ids where label='vendor_b'),'abcdefab-cdef-4abc-8abc-000000000007','Future',(now() at time zone 'America/Chicago')::date+1));
insert into storage.objects(bucket_id,name,metadata) select 'vendor-price-sheets',l.object_path,'{"size":12,"mimetype":"application/pdf"}'::jsonb from public.vendor_price_lists l join pg_temp.eigsti_pricing_ids t on t.id=l.id;
select public.finish_vendor_price_list(id) from pg_temp.eigsti_pricing_ids where label like 'list_%';
create function pg_temp.pricing_rows(p numeric,u text default 'each',c boolean default true) returns jsonb language sql immutable as $helper$select jsonb_build_array(jsonb_build_object('description','2x12x12 Doug Fir #2 untreated lumber','sku','DF1212','comparison','2x12x12 Douglas Fir #2 untreated','unit',u,'quantity',1,'price',p,'source','PDF page 1','confirmed',c));$helper$;
set local role authenticated;
insert into pg_temp.eigsti_pricing_results(result) values(ok((select contact_types @> array['vendor','subcontractor'] from public.subcontractors where id=(select id from pg_temp.eigsti_pricing_ids where label='vendor_a')),'Same contact supports Vendor and Subcontractor'));
insert into pg_temp.eigsti_pricing_results(result) values(ok((select contact_types=array['subcontractor'] from public.subcontractors where id=(select id from pg_temp.eigsti_pricing_ids where label='legacy')),'Legacy contact keeps its type'));
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.begin_vendor_price_list('abcdefab-cdef-4abc-8abc-000000000008',(select id from pg_temp.eigsti_pricing_ids where label='legacy'),'General',current_date,null,'','x.pdf','application/pdf',12)$q$,'22023','Choose an active Vendor contact','Non-vendor cannot own pricing'));
insert into pg_temp.eigsti_pricing_results(result) values(lives_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_a'),'abcdefab-cdef-4abc-8abc-000000000009',1,pg_temp.pricing_rows(19.99),true)$q$,'PM publishes reviewed rows'));
insert into pg_temp.eigsti_pricing_results(result) values(lives_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_b'),'abcdefab-cdef-4abc-8abc-000000000010',1,pg_temp.pricing_rows(18.50),true)$q$,'Another vendor publishes equivalent product'));
insert into pg_temp.eigsti_pricing_results(result) values(is(jsonb_array_length(public.search_vendor_prices('2 x 12 x 12 doug fir')->'items'),2,'Size separators and species aliases match'));
insert into pg_temp.eigsti_pricing_results(result) values(is((public.search_vendor_prices('DF1212')->'items'->0->>'price')::numeric,18.50::numeric,'Equivalent prices cheapest first'));
insert into pg_temp.eigsti_pricing_results(result) values(is((public.search_vendor_prices('DF1212')->'items'->1->>'lowest')::numeric,18.50::numeric,'Group minimum computed before display limit'));
insert into pg_temp.eigsti_pricing_results(result) values(lives_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_a'),'abcdefab-cdef-4abc-8abc-000000000009',1,pg_temp.pricing_rows(19.99),true)$q$,'Same publish retry acknowledged'));
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_a'),'abcdefab-cdef-4abc-8abc-000000000009',1,pg_temp.pricing_rows(1),true)$q$,'23505','Request changed','Changed publish retry denied'));
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_new'),'abcdefab-cdef-4abc-8abc-000000000011',1,pg_temp.pricing_rows(17,'each',false),true)$q$,'22023','Confirm every product price and selling unit','Unconfirmed extracted rows cannot publish'));
insert into pg_temp.eigsti_pricing_results(result) values(is((public.search_vendor_prices('DF1212')->'items'->0->>'price')::numeric,18.50::numeric,'Failed publication leaves previous catalogs intact'));
insert into pg_temp.eigsti_pricing_results(result) values(lives_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_new'),'abcdefab-cdef-4abc-8abc-000000000012',1,pg_temp.pricing_rows(17,'each',false),false)$q$,'PM can save an unconfirmed draft'));
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_new'),'abcdefab-cdef-4abc-8abc-000000000013',1,pg_temp.pricing_rows(17),true)$q$,'22023','Price sheet changed. Reopen it before saving.','Concurrent stale version rejected'));
insert into pg_temp.eigsti_pricing_results(result) values(lives_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_new'),'abcdefab-cdef-4abc-8abc-000000000014',2,pg_temp.pricing_rows(17),true)$q$,'New monthly catalog replaces current atomically'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select status from public.vendor_price_lists where id=(select id from pg_temp.eigsti_pricing_ids where label='list_a')),'superseded','Previous file remains historical'));
insert into pg_temp.eigsti_pricing_results(result) values(is(jsonb_array_length(public.search_vendor_prices('DF1212')->'items'),2,'Search contains one current list per vendor/catalog'));
insert into pg_temp.eigsti_pricing_results(result) values(is((public.search_vendor_prices('DF1212')->'items'->0->>'price')::numeric,17::numeric,'New current price used'));
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_future'),'abcdefab-cdef-4abc-8abc-000000000015',1,pg_temp.pricing_rows(1),true)$q$,'22023','Only currently effective pricing may be published','Future price sheet cannot replace current prices'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_pricing_results(result) values(is(jsonb_array_length(public.search_vendor_prices('DF1212')->'items'),2,'Lead can compare current pricing'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select count(*) from public.vendor_price_lists where id=(select id from pg_temp.eigsti_pricing_ids where label='list_future')),0::bigint,'Lead cannot read draft metadata'));
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='list_future'),'abcdefab-cdef-4abc-8abc-000000000016',1,pg_temp.pricing_rows(1),true)$q$,'42501','PM or administrator required','Lead cannot publish'));
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.withdraw_vendor_price_list((select id from pg_temp.eigsti_pricing_ids where label='list_b'),'abcdefab-cdef-4abc-8abc-000000000017')$q$,'42501','PM or administrator required','Lead cannot withdraw'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.search_vendor_prices('DF1212')$q$,'42501','PM or lead required','Helper cannot search pricing'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select count(*) from public.vendor_price_lists where id in ((select id from pg_temp.eigsti_pricing_ids where label='list_b'),(select id from pg_temp.eigsti_pricing_ids where label='list_new'))),0::bigint,'Helper direct list read denied'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select count(*) from public.vendor_price_items where list_id=(select id from pg_temp.eigsti_pricing_ids where label='list_new')),0::bigint,'Helper direct item read denied'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select count(*) from storage.objects where bucket_id='vendor-price-sheets' and name like (select id from pg_temp.eigsti_pricing_ids where label='vendor_a')::text||'/%'),0::bigint,'Helper source download policy denied'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_pricing_results(result) values(lives_ok($q$select public.withdraw_vendor_price_list((select id from pg_temp.eigsti_pricing_ids where label='list_b'),'abcdefab-cdef-4abc-8abc-000000000018')$q$,'PM withdraws outdated catalog'));
insert into pg_temp.eigsti_pricing_results(result) values(is(jsonb_array_length(public.search_vendor_prices('DF1212')->'items'),1,'Withdrawn catalog removed from results'));
reset role;
insert into pg_temp.eigsti_pricing_results(result) values(ok(not has_table_privilege('authenticated','public.vendor_price_items','INSERT'),'No direct price writes granted'));
insert into pg_temp.eigsti_pricing_results(result) values(ok(not has_function_privilege('anon','public.search_vendor_prices(text)','execute'),'Anonymous search forbidden'));
insert into pg_temp.eigsti_pricing_results(result) values(ok((select not public from storage.buckets where id='vendor-price-sheets'),'Original file bucket is private'));

-- Separate unit, pack and grade are never promoted as equivalent bargains.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_pricing_ids values
('unit',pg_temp.pricing_sheet((select id from pg_temp.eigsti_pricing_ids where label='vendor_b'),'abcdefab-cdef-4abc-8abc-000000000020','Unit')),
('pack',pg_temp.pricing_sheet((select id from pg_temp.eigsti_pricing_ids where label='vendor_b'),'abcdefab-cdef-4abc-8abc-000000000021','Pack')),
('grade',pg_temp.pricing_sheet((select id from pg_temp.eigsti_pricing_ids where label='vendor_b'),'abcdefab-cdef-4abc-8abc-000000000022','Grade'));
insert into storage.objects(bucket_id,name,metadata) select 'vendor-price-sheets',l.object_path,'{"size":12,"mimetype":"application/pdf"}'::jsonb from public.vendor_price_lists l join pg_temp.eigsti_pricing_ids t on t.id=l.id where t.label in ('unit','pack','grade');
select public.finish_vendor_price_list(id) from pg_temp.eigsti_pricing_ids where label in ('unit','pack','grade');
select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='unit'),'abcdefab-cdef-4abc-8abc-000000000023',1,pg_temp.pricing_rows(2,'linear_ft'),true);
select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='pack'),'abcdefab-cdef-4abc-8abc-000000000024',1,jsonb_set(pg_temp.pricing_rows(100),'{0,quantity}','10'),true);
select public.save_vendor_price_rows((select id from pg_temp.eigsti_pricing_ids where label='grade'),'abcdefab-cdef-4abc-8abc-000000000025',1,jsonb_set(pg_temp.pricing_rows(9),'{0,comparison}','"2x12x12 Douglas Fir #3 untreated"'),true);
set local role authenticated;
insert into pg_temp.eigsti_pricing_results(result) values(is((select (x->>'lowest')::numeric from jsonb_array_elements(public.search_vendor_prices('DF1212')->'items') x where x->>'unit'='linear_ft'),2::numeric,'Linear-foot price has its own comparison group'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select (x->>'lowest')::numeric from jsonb_array_elements(public.search_vendor_prices('DF1212')->'items') x where (x->>'quantity')::numeric=10),100::numeric,'Pack quantity has its own comparison group'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select (x->>'lowest')::numeric from jsonb_array_elements(public.search_vendor_prices('DF1212')->'items') x where x->>'comparison' like '%#3%'),9::numeric,'Different grade has its own comparison group'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select (x->>'lowest')::numeric from jsonb_array_elements(public.search_vendor_prices('DF1212')->'items') x where x->>'unit'='each' and (x->>'quantity')::numeric=1 and x->>'comparison' like '%#2%'),17::numeric,'Cheaper incompatible goods do not replace equivalent minimum'));
select public.withdraw_vendor_price_list((select id from pg_temp.eigsti_pricing_ids where label='list_future'),'abcdefab-cdef-4abc-8abc-000000000026');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_pricing_results(result) values(is((select count(*) from public.vendor_price_lists where id=(select id from pg_temp.eigsti_pricing_ids where label='list_future')),0::bigint,'Discarded unpublished list remains hidden from leads'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select count(*) from public.vendor_price_items where list_id=(select id from pg_temp.eigsti_pricing_ids where label='list_future')),0::bigint,'Discarded draft rows remain hidden from leads'));
insert into pg_temp.eigsti_pricing_results(result) values(is((select count(*) from storage.objects where bucket_id='vendor-price-sheets' and name=(select object_path from public.vendor_price_lists where id=(select id from pg_temp.eigsti_pricing_ids where label='list_future'))),0::bigint,'Discarded draft source remains hidden from leads'));
reset role;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
update public.app_users set active=false where id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
insert into pg_temp.eigsti_pricing_results(result) values(throws_ok($q$select public.search_vendor_prices('DF1212')$q$,'42501','PM or lead required','Inactive PM loses price access'));
reset role;
do $validation$ begin if exists(select 1 from pg_temp.eigsti_pricing_results where result not like 'ok %') then raise exception 'Vendor pricing checks failed';end if;end;$validation$;
select result from pg_temp.eigsti_pricing_results order by ordinal;
select * from finish();
rollback;
