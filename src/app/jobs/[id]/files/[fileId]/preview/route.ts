import {authClient} from '../../../../../../lib/supabase-server';
import {appConfig} from '../../../../../../lib/config';
import {FileSession} from '../../../../../../server/files.ts';
import {AppError} from '../../../../../../domain/access.ts';
import {fileUuid} from '../../../../../../domain/files.ts';
export const dynamic='force-dynamic';
export async function GET(_request:Request,{params}:{params:Promise<{id:string;fileId:string}>}) {
  const headers={'Cache-Control':'private, no-store','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'none'; sandbox"};
  try{
    const {id,fileId}=await params;fileUuid(id);fileUuid(fileId);
    const config=appConfig();if(!config)return new Response('Photo unavailable.',{status:503,headers});
    const client=await authClient(true),{data}=await client.auth.getSession();
    if(!data.session)return new Response('Please sign in.',{status:401,headers});
    const gateway=new FileSession(config,data.session.access_token);await gateway.getActor();
    const photo=await gateway.photoPreview(id,fileId);
    return new Response(photo.body,{headers:{...headers,'Content-Type':photo.mime,'Content-Disposition':'inline'}});
  }catch(error){return new Response('Photo unavailable.',{status:error instanceof AppError?error.status:503,headers});}
}
