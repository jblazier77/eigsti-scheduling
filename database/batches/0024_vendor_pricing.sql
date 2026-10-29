begin;
do $preflight$ begin if not exists(select 1 from pg_constraint where conrelid='public.visits'::regclass and conname='visits_monday_saturday_check') then raise exception 'Requires 0023';end if; if to_regclass('public.vendor_price_lists') is not null or exists(select 1 from storage.buckets where id='vendor-price-sheets') then raise exception '0024 already present; do not rerun';end if;end; $preflight$;
-- Apply once after 0023. Company contacts and private reviewed vendor pricing.
alter table public.subcontractors add column contact_types text[] not null default array['subcontractor']::text[] check(cardinality(contact_types) between 1 and 2 and contact_types <@ array['vendor','subcontractor']::text[]),add column notes text not null default '' check(length(notes)<=2000);
create or replace function public.save_subcontractor(p_id uuid,p_request_id uuid,p_patch jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); patch jsonb:='{}'; k text; v text; ids jsonb; payload jsonb; previous private.command_requests%rowtype; s public.subcontractors%rowtype; before_data jsonb:='{}';
begin
 perform 1 from public.app_users where id=actor and active and roles&&array['pm','admin']::text[] for share;
 if not found then raise exception using errcode='42501',message='Directory manager required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 if p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 for k in select jsonb_object_keys(p_patch) loop
  if k='contact_types' then
   if jsonb_typeof(p_patch->k)<>'array' or jsonb_array_length(p_patch->k) not between 1 and 2 or exists(select 1 from jsonb_array_elements_text(p_patch->k) x where x not in ('vendor','subcontractor')) then raise exception using errcode='22023',message='Choose Vendor and/or Subcontractor'; end if;
   patch:=patch||jsonb_build_object(k,p_patch->k);
  elsif k='notes' and jsonb_typeof(p_patch->k)='string' then
   if length(p_patch->>k)>2000 then raise exception using errcode='22023',message='Contact notes too long'; end if;patch:=patch||jsonb_build_object(k,p_patch->k);
  elsif k='trades' then patch:=patch||private.classification_patch(jsonb_build_object(k,p_patch->k));
  elsif k='archive' and p_patch->k='true'::jsonb then patch:=patch||jsonb_build_object(k,true);
  elsif k in ('name','phone','email') and jsonb_typeof(p_patch->k)='string' then
   v:=btrim(p_patch->>k);
   if length(p_patch->>k)>(case k when 'name' then 100 when 'phone' then 40 else 254 end) or (p_patch->>k) ~ '[[:cntrl:]]' or (k='name' and v='') then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
   if k='phone' and v<>'' then perform private.phone_action(v); end if;
   if k='email' and v<>'' and v !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
   patch:=patch||jsonb_build_object(k,v);
  else raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 end loop;
 if patch?'archive' and patch<>'{"archive":true}'::jsonb then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 payload:=jsonb_build_object('id',p_id,'patch',patch);
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':save_subcontractor:'||p_request_id::text,0));
 select * into previous from private.command_requests where actor_id=actor and operation='save_subcontractor' and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',previous.result_id);
 end if;
 -- Serialize directory capacity and row edits; no scheduling/queue locks needed.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:subcontractors',0));
 if p_id is null then
  if not(patch?&array['name','phone','email','trades']) or patch?'archive' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
  if (select count(*) from public.subcontractors where archived_at is null)>=500 then raise exception using errcode='22023',message='Directory limit reached'; end if;
  insert into public.subcontractors(name,phone,phone_action,email,trades,created_by,updated_by) values(patch->>'name',patch->>'phone',case when patch->>'phone'='' then null else private.phone_action(patch->>'phone') end,patch->>'email',array(select jsonb_array_elements_text(patch->'trades')),actor,actor) returning * into s;
 else
  select * into s from public.subcontractors where id=p_id and archived_at is null for update;
  if not found then raise exception using errcode='P0002',message='Subcontractor unavailable'; end if;
  before_data:=to_jsonb(s);
  update public.subcontractors set name=coalesce(patch->>'name',name),phone=coalesce(patch->>'phone',phone),
   phone_action=case when patch?'phone' then case when patch->>'phone'='' then null else private.phone_action(patch->>'phone') end else phone_action end,
   email=coalesce(patch->>'email',email),trades=case when patch?'trades' then array(select jsonb_array_elements_text(patch->'trades')) else trades end,
   archived_at=case when patch?'archive' then clock_timestamp() else archived_at end,updated_at=clock_timestamp(),updated_by=actor where id=p_id returning * into s;
 end if;
 if patch?'contact_types' or patch?'notes' then update public.subcontractors set contact_types=case when patch?'contact_types' then array(select distinct jsonb_array_elements_text(patch->'contact_types')) else contact_types end,notes=coalesce(patch->>'notes',notes) where id=s.id returning * into s; end if;
 insert into private.subcontractor_events(subcontractor_id,actor_id,request_id,before_state,after_state) values(s.id,actor,p_request_id,before_data,to_jsonb(s));
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(actor,p_request_id,'save_subcontractor',payload,s.id);
 return jsonb_build_object('id',s.id);
end; $$;
create function private.pricing_reader() returns boolean language sql stable security definer set search_path='' as $$select private.has_role('pm') or private.has_role('admin') or private.has_role('lead');$$;
create function private.pricing_writer() returns boolean language sql stable security definer set search_path='' as $$select private.has_role('pm') or private.has_role('admin');$$;
create function private.pricing_normalize(s text) returns text language sql immutable set search_path='' as $$select btrim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(lower(replace(coalesce(s,''),chr(215),'x')),'doug(las)?\.?[[:space:]]*fir|\mdf\M','douglas fir','g'),'([0-9])[[:space:]]*x[[:space:]]*','\1x','g'),'[^a-z0-9#./x -]+',' ','g'),'[[:space:]]+',' ','g'));$$;
create table public.vendor_price_lists(
 id uuid primary key default gen_random_uuid(),vendor_id uuid not null references public.subcontractors(id),catalog text not null check(length(btrim(catalog)) between 1 and 100),effective_on date not null,expires_on date check(expires_on>=effective_on),notes text not null default '' check(length(notes)<=2000),filename text not null check(length(filename) between 1 and 180 and filename !~ '[/\\[:cntrl:]]'),mime_type text not null check(mime_type in ('application/pdf','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv')),byte_size bigint not null check(byte_size between 1 and 20971520),object_path text not null unique,status text not null default 'uploading' check(status in ('uploading','draft','published','superseded','withdrawn')),version integer not null default 0,created_by uuid not null references public.app_users(id),created_at timestamptz not null default now(),published_at timestamptz,uploaded_at timestamptz,
 check(object_path=vendor_id::text||'/'||id::text)
);
create unique index vendor_price_current on public.vendor_price_lists(vendor_id,lower(catalog)) where status='published';
create table public.vendor_price_items(list_id uuid not null references public.vendor_price_lists(id),line_no integer not null,description text not null check(length(description)<=500),sku text not null default '' check(length(sku)<=100),comparison text not null default '' check(length(comparison)<=500),unit text not null default '' check(length(unit)<=30),quantity numeric not null check(quantity>0 and quantity<=100000),price numeric check(price>=0 and price<=100000000),source text not null default '' check(length(source)<=180),confirmed boolean not null default false,primary key(list_id,line_no));
create index vendor_price_items_match on public.vendor_price_items(comparison,unit,quantity,price);
alter table public.vendor_price_lists enable row level security;
alter table public.vendor_price_items enable row level security;
revoke all on public.vendor_price_lists,public.vendor_price_items from public,anon,authenticated;
grant select on public.vendor_price_lists,public.vendor_price_items to authenticated;
create policy price_lists_read on public.vendor_price_lists for select to authenticated using(private.pricing_reader() and (private.pricing_writer() or published_at is not null and status in ('published','superseded','withdrawn')));
create policy price_items_read on public.vendor_price_items for select to authenticated using(exists(select 1 from public.vendor_price_lists l where l.id=list_id));
create function public.begin_vendor_price_list(p_request uuid,p_vendor uuid,p_catalog text,p_effective date,p_expires date,p_notes text,p_filename text,p_mime text,p_bytes bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare prior private.command_requests%rowtype;payload jsonb;v_id uuid;
begin
 if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:pricing',0)); perform id from public.app_users where id=auth.uid() for share; if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 if p_request is null or p_effective is null or p_catalog is null or length(btrim(p_catalog)) not between 1 and 100 or p_notes is null or length(p_notes)>2000 or p_filename is null or length(p_filename) not between 1 and 180 or p_filename ~ '[/\\[:cntrl:]]' or p_mime not in ('application/pdf','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv') or p_mime is null or p_bytes is null or p_bytes not between 1 and 20971520 or p_expires<p_effective then raise exception using errcode='22023',message='Invalid price sheet';end if;
 payload:=jsonb_build_object('vendor',p_vendor,'catalog',btrim(p_catalog),'effective',p_effective,'expires',p_expires,'notes',p_notes,'filename',p_filename,'mime',p_mime,'bytes',p_bytes);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':price_upload:'||p_request::text,0));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='price_upload' and request_id=p_request;
 if found then if prior.payload<>payload then raise exception using errcode='23505',message='Request changed';end if;return jsonb_build_object('id',prior.result_id);end if;
 if not exists(select 1 from public.subcontractors where id=p_vendor and archived_at is null and 'vendor'=any(contact_types)) then raise exception using errcode='22023',message='Choose an active Vendor contact';end if;
 if (select count(*) from public.vendor_price_lists where status in ('uploading','draft'))>=100 then raise exception using errcode='22023',message='Too many unfinished price sheets';end if;
 v_id:=gen_random_uuid();insert into public.vendor_price_lists(id,vendor_id,catalog,effective_on,expires_on,notes,filename,mime_type,byte_size,object_path,created_by) values(v_id,p_vendor,btrim(p_catalog),p_effective,p_expires,p_notes,p_filename,p_mime,p_bytes,p_vendor::text||'/'||v_id::text,auth.uid());
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'price_upload',p_request,payload,v_id);return jsonb_build_object('id',v_id);
end;$$;
create function public.finish_vendor_price_list(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare l public.vendor_price_lists%rowtype;o storage.objects%rowtype;
begin
 if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:pricing',0)); perform id from public.app_users where id=auth.uid() for share; if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 select * into l from public.vendor_price_lists where id=p_id for update;if not found then raise exception using errcode='P0002',message='Price sheet unavailable';end if;
 if l.status<>'uploading' then return to_jsonb(l);end if;
 select * into o from storage.objects where bucket_id='vendor-price-sheets' and name=l.object_path;
 if not found then raise exception using errcode='55000',message='Upload is not confirmed yet';end if;
 if (o.metadata->>'size')::bigint is distinct from l.byte_size or o.metadata->>'mimetype' is distinct from l.mime_type then raise exception using errcode='22023',message='Uploaded file does not match';end if;
 update public.vendor_price_lists set status='draft',uploaded_at=clock_timestamp(),version=version+1 where id=l.id returning * into l;return to_jsonb(l);
end;$$;
create function public.save_vendor_price_rows(p_id uuid,p_request uuid,p_version integer,p_rows jsonb,p_publish boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare l public.vendor_price_lists%rowtype;prior private.command_requests%rowtype;payload jsonb;r jsonb;n integer:=0;manager uuid:=auth.uid();today date:=(now() at time zone 'America/Chicago')::date;
begin
 if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:pricing',0)); perform id from public.app_users where id=auth.uid() for share; if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 if p_request is null or p_version is null or p_publish is null or jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows)>2000 or p_publish and jsonb_array_length(p_rows)=0 then raise exception using errcode='22023',message='Invalid price rows';end if;
 select * into l from public.vendor_price_lists where id=p_id for update;if not found then raise exception using errcode='P0002',message='Price sheet unavailable';end if;
 payload:=jsonb_build_object('list',p_id,'version',p_version,'rows',p_rows,'publish',p_publish);
 select * into prior from private.command_requests where actor_id=manager and operation='price_rows' and request_id=p_request;
 if found then if prior.payload<>payload then raise exception using errcode='23505',message='Request changed';end if;return jsonb_build_object('id',l.id,'version',p_version+1,'published',p_publish);end if;
 if l.status<>'draft' or l.version<>p_version then raise exception using errcode='22023',message='Price sheet changed. Reopen it before saving.';end if;
 if p_publish and (l.effective_on>today or l.expires_on<today) then raise exception using errcode='22023',message='Only currently effective pricing may be published';end if;
 if p_publish and not exists(select 1 from public.subcontractors where id=l.vendor_id and archived_at is null and 'vendor'=any(contact_types)) then raise exception using errcode='22023',message='Vendor is no longer active';end if;
 if p_publish and exists(select 1 from public.vendor_price_lists where vendor_id=l.vendor_id and lower(catalog)=lower(l.catalog) and status='published' and effective_on>l.effective_on) then raise exception using errcode='22023',message='A newer price list is already current';end if;
 delete from public.vendor_price_items where list_id=p_id;
 for r in select value from jsonb_array_elements(p_rows) loop
  n:=n+1;
  if jsonb_typeof(r)<>'object' or not(r ?& array['description','sku','comparison','unit','quantity','price','source','confirmed']) or jsonb_typeof(r->'description')<>'string' or jsonb_typeof(r->'sku')<>'string' or jsonb_typeof(r->'comparison')<>'string' or jsonb_typeof(r->'unit')<>'string' or jsonb_typeof(r->'quantity')<>'number' or jsonb_typeof(r->'source')<>'string' or jsonb_typeof(r->'confirmed')<>'boolean' or (r->'price'<>'null'::jsonb and jsonb_typeof(r->'price')<>'number') then raise exception using errcode='22023',message='Invalid price row';end if;
  if p_publish and (btrim(r->>'description')='' or private.pricing_normalize(r->>'comparison')='' or r->>'unit' not in ('each','linear_ft','sq_ft','sq_yard','board_ft','mbf','bundle','box','bag','gallon','ton') or r->'price'='null'::jsonb or r->'confirmed'<>'true'::jsonb) then raise exception using errcode='22023',message='Confirm every product price and selling unit';end if;
  insert into public.vendor_price_items(list_id,line_no,description,sku,comparison,unit,quantity,price,source,confirmed) values(p_id,n,r->>'description',r->>'sku',r->>'comparison',r->>'unit',(r->>'quantity')::numeric,(r->>'price')::numeric,r->>'source',(r->>'confirmed')::boolean);
 end loop;
 if p_publish then update public.vendor_price_lists set status='superseded' where vendor_id=l.vendor_id and lower(catalog)=lower(l.catalog) and status='published';end if;
 update public.vendor_price_lists set status=case when p_publish then 'published' else 'draft' end,version=version+1,published_at=case when p_publish then clock_timestamp() else null end where id=p_id;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(manager,'price_rows',p_request,payload,p_id);return jsonb_build_object('id',p_id,'version',p_version+1,'published',p_publish);
end;$$;
create function public.withdraw_vendor_price_list(p_id uuid,p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare l public.vendor_price_lists%rowtype;
begin
 if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:pricing',0)); perform id from public.app_users where id=auth.uid() for share; if not private.pricing_writer() then raise exception using errcode='42501',message='PM or administrator required';end if;
 if p_request is null then raise exception using errcode='22023',message='Request required';end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:pricing',0));select * into l from public.vendor_price_lists where id=p_id for update;
 if not found then raise exception using errcode='P0002',message='Price sheet unavailable';end if;
 update public.vendor_price_lists set status='withdrawn',version=version+1 where id=p_id and status<>'withdrawn';return jsonb_build_object('id',p_id);
end;$$;
create function public.search_vendor_prices(p_query text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare q text;result jsonb;total integer;
begin
 if not private.pricing_reader() then raise exception using errcode='42501',message='PM or lead required';end if;
 if p_query is null or length(p_query)>200 then raise exception using errcode='22023',message='Search is too long';end if;q:=private.pricing_normalize(p_query);
 with matches as(select i.*,l.vendor_id,l.catalog,l.effective_on,l.expires_on,l.notes,v.name vendor_name,private.pricing_normalize(i.comparison) match_key,l.effective_on<((now() at time zone 'America/Chicago')::date-90) stale from public.vendor_price_items i join public.vendor_price_lists l on l.id=i.list_id join public.subcontractors v on v.id=l.vendor_id where l.status='published' and l.effective_on<=(now() at time zone 'America/Chicago')::date and (l.expires_on is null or l.expires_on>=(now() at time zone 'America/Chicago')::date) and v.archived_at is null and 'vendor'=any(v.contact_types) and not exists(select 1 from regexp_split_to_table(q,'[[:space:]]+') token where token<>'' and position(token in private.pricing_normalize(i.description||' '||i.comparison||' '||i.sku))=0)),ranked as(select m.*,min(price) over(partition by match_key,unit,quantity) lowest from matches m),limited as(select * from ranked order by match_key,unit,quantity,price,vendor_name,list_id,line_no limit 100)
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(x) order by x.match_key,x.unit,x.quantity,x.price,x.vendor_name,x.list_id,x.line_no) from limited x),'[]'::jsonb),'total',(select count(*) from matches)) into result;return result;
end;$$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('vendor-price-sheets','vendor-price-sheets',false,20971520,array['application/pdf','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv']);
create policy vendor_price_storage_read on storage.objects for select to authenticated using(bucket_id='vendor-price-sheets' and exists(select 1 from public.vendor_price_lists l where l.object_path=name));
create policy vendor_price_storage_upload on storage.objects for insert to authenticated with check(bucket_id='vendor-price-sheets' and private.pricing_writer() and exists(select 1 from public.vendor_price_lists l where l.object_path=name and l.status='uploading' and l.created_by=auth.uid()));
revoke all on function private.pricing_reader(),private.pricing_writer(),private.pricing_normalize(text) from public,anon,authenticated;
-- Policies need safe role predicates; functions expose no data and still check active membership.
grant execute on function private.pricing_reader(),private.pricing_writer() to authenticated;
revoke all on function public.begin_vendor_price_list(uuid,uuid,text,date,date,text,text,text,bigint),public.finish_vendor_price_list(uuid),public.save_vendor_price_rows(uuid,uuid,integer,jsonb,boolean),public.withdraw_vendor_price_list(uuid,uuid),public.search_vendor_prices(text) from public,anon,authenticated;
grant execute on function public.begin_vendor_price_list(uuid,uuid,text,date,date,text,text,text,bigint),public.finish_vendor_price_list(uuid),public.save_vendor_price_rows(uuid,uuid,integer,jsonb,boolean),public.withdraw_vendor_price_list(uuid,uuid),public.search_vendor_prices(text) to authenticated;
notify pgrst,'reload schema';

savepoint pricing_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
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

rollback to savepoint pricing_checks;
release savepoint pricing_checks;
commit;
select 40::integer as checks,0::integer as failed,'0024 applied; synthetic fixtures removed'::text as result;
