-- Apply once after 0020. Preserve existing workspace receipts; add atomic crew setup.
begin;
create or replace function public.create_job_workspace(p_request_id uuid,p_customer text,p_phone text,p_address text,p_classification jsonb,p_details jsonb,p_priority jsonb,p_work jsonb,p_contacts jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb; prior private.command_requests%rowtype; result jsonb; v_job uuid; item jsonb; item_request uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null or jsonb_typeof(p_work) is distinct from 'array' or jsonb_typeof(p_contacts) is distinct from 'array' or jsonb_array_length(p_work)>20 or jsonb_array_length(p_contacts)>20 then raise exception using errcode='22023',message='Invalid job setup'; end if;
 payload:=jsonb_build_object('customer',p_customer,'phone',p_phone,'address',p_address,'classification',p_classification,'details',p_details,'priority',p_priority,'work',p_work,'contacts',p_contacts);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job_workspace:'||p_request_id::text,0));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_job_workspace' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_classified_job:'||p_request_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job:'||p_request_id::text,0));
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('create_job','create_classified_job')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_classified_job(p_request_id,p_customer,p_phone,p_address,p_classification);v_job:=(result->>'id')::uuid;
 if p_details is null or jsonb_typeof(p_details)<>'object' or exists(select 1 from jsonb_object_keys(p_details) k where k not in ('title','scope','access_notes')) then raise exception using errcode='22023',message='Invalid job setup'; end if;
 if p_details<>'{}'::jsonb then perform public.update_job(v_job,p_details); end if;
 perform public.save_job_priority(v_job,p_request_id,p_priority);
 -- create_job supplies one Whole job item; remove only this newly-created placeholder
 -- when explicit task drafts were supplied, before any dates or ownership exist.
 if jsonb_array_length(p_work)>0 then delete from public.work_items where job_id=v_job; end if;
 for item in select value from jsonb_array_elements(p_work) loop
  item_request:=gen_random_uuid();
  perform public.create_staffed_work(v_job,item_request,item->'values',item->'plan',(item->>'helpers')::integer,item->'materials',item->'days',coalesce(item->'named_helpers','[]'::jsonb));
 end loop;
 for item in select value from jsonb_array_elements(p_contacts) loop perform public.create_job_contact(v_job,gen_random_uuid(),item); end loop;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_job_workspace',p_request_id,payload,v_job);
 return result;
end; $$;
notify pgrst,'reload schema';
commit;
