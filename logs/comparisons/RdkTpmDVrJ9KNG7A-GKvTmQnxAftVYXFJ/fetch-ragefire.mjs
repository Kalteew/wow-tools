import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {WclService,loadConfig} from 'file:///C:/Users/Yaya/source/tools/warcraftlogs-mcp-fork/dist/index.mjs';
const dir=path.dirname(new URL(import.meta.url).pathname).replace(/^\/([A-Z]:)/i,'$1');
const service=WclService.fromConfig(loadConfig());
const auraMode=process.argv.includes('--aura');
const debuffMode=process.argv.includes('--debuffs');
const metaMode=process.argv.includes('--meta');
const mode=auraMode?'aura-tick':debuffMode?'burning-wound':metaMode?'meta-casts':'ragefire';
const abilityIDs=auraMode?[258922,427908,427910,427911]:debuffMode?[391191]:metaMode?[191427]:[390197];
const players=[{name:'azaelle',report:'RdkTpmDVrJ9KNG7A',fight:1,actor:1,start:154984,end:1854810},{name:'comparator',report:'GKvTmQnxAftVYXFJ',fight:8,actor:436,start:6764714,end:8467919}];
function record(p,status,summary){
 const result=spawnSync('powershell',['-NoProfile','-File','C:/Users/Yaya/.codex/skills/warcraftlogs-core/scripts/record_wcl_request.ps1','-ReportCode',p.report,'-Tool',`get_${mode}_events`,'-ArgsJson',JSON.stringify({fightID:p.fight,sourceID:p.actor,abilityIDs,startTime:p.start,endTime:p.end} ),'-Status',status,'-SummaryJson',JSON.stringify(summary),'-LogsRoot','C:/Users/Yaya/source/tools/wow-tools/logs'],{encoding:'utf8',windowsHide:true});
 if(result.status!==0)throw new Error('Request logging failed');
}
const results=await Promise.allSettled(players.map(async p=>{
 const file=path.join(dir,`${p.name}-${mode}-events.json`);
 if(fs.existsSync(file)){console.log(JSON.stringify({player:p.name,cached:true}));return;}
 try{
  const fields=abilityIDs.map(id=>`${auraMode?'s'+id:'events'}:events(dataType:${debuffMode?'Debuffs':metaMode?'Casts':'DamageDone'} fightIDs:[${p.fight}] sourceID:${p.actor} abilityID:${id} startTime:${p.start} endTime:${p.end} limit:10000 useAbilityIDs:true useActorIDs:true){data nextPageTimestamp}`).join(' ');
  const query=`query AuraDamage($code:String!){reportData{report(code:$code){${fields}}}}`;
  const result=await service.client.query('https://www.warcraftlogs.com',query,{code:p.report},{mode:'public'});
  fs.writeFileSync(file,JSON.stringify(result,null,2));
  const summary=Object.fromEntries(Object.entries(result.reportData.report).map(([key,e])=>[key,{count:e.data.length,nextPageTimestamp:e.nextPageTimestamp}]));
  record(p,'success',{file,...summary});
  console.log(JSON.stringify({player:p.name,...summary,sample:Object.values(result.reportData.report)[0].data[0]}));
 }catch(e){record(p,'error',{code:e.code,message:e.message});throw e;}
}));
for(const result of results)if(result.status==='rejected')console.log(JSON.stringify({error:result.reason.message}));
