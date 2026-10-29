import 'server-only';
import {authClient} from './supabase-server';
import {appConfig} from './config';
import {PricingSession} from '../server/pricing.ts';
import {requirePricing} from '../domain/pricing.ts';
import {AppError} from '../domain/access.ts';
export async function pricingSession(write=false){const config=appConfig();if(!config)throw new AppError('schema_pending',503,'Pricing connection is not configured.');const client=await authClient(write),{data}=await client.auth.getSession();if(!data.session)throw new AppError('sign_in_required',401,'Please sign in again.');const gateway=new PricingSession(config,data.session.access_token),actor=await gateway.getActor();requirePricing(actor,write);return {gateway,actor};}
