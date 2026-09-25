import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {WclService,loadConfig} from 'file:///C:/Users/Yaya/source/tools/warcraftlogs-mcp-fork/dist/index.mjs';
const report='RdkTpmDVrJ9KNG7A';
const dir='C:/Users/Yaya/source/tools/wow-tools/logs/comparisons/RdkTpmDVrJ9KNG7A-GKvTmQnxAftVYXFJ';
const service=WclService.fromConfig(loadConfig());
const options={fight:1,accessMode:'public'};
function record(tool,args,status,summary,errorCode=''){
 const argv=['-NoProfile','-File','C:/Users/Yaya/.codex/skills/warcraftlogs-core/scripts/record_wcl_request.ps1','-ReportCode',report,'-Tool',tool,'-ArgsJson',JSON.stringify(args),'-Status',status,'-SummaryJson',JSON.stringify(summary),'-LogsRoot','C:/Users/Yaya/source/tools/wow-tools/logs'];
 if(errorCode)argv.push('-ErrorCode',errorCode);
 const result=spawnSync('powershell',argv,{encoding:'utf8',windowsHide:true});
 if(result.status!==0)throw Error('History recording failed: '+result.stderr);
}
async function request(tool,file,args,fn){
 const target=path.join(dir,file);
 if(fs.existsSync(target)){console.log(JSON.stringify({tool,cached:true,file}));return JSON.parse(fs.readFileSync(target,'utf8'));}
 try{const result=await fn();fs.writeFileSync(target,JSON.stringify(result,null,2));record(tool,args,'success',{file,bytes:fs.statSync(target).size});console.log(JSON.stringify({tool,status:'success',file,bytes:fs.statSync(target).size}));return result;}
 catch(e){record(tool,args,'error',{code:e.code??'UNKNOWN',message:e.message},e.code??'UNKNOWN');console.log(JSON.stringify({tool,status:'error',code:e.code??'UNKNOWN',message:e.message}));return null;}
}
const outcomes=await Promise.allSettled([
 request('get_buffs','azaelle-buffs.json',{report,fightID:1,targetID:1},()=>service.getTable(report,'Buffs',{...options,filter:{targetID:1},maxEntries:150,maxPayloadBytes:500000})),
 request('list_dungeon_pulls','azaelle-pulls.json',{report,fightID:1},()=>service.listDungeonPulls(report,options))
]);
for(const outcome of outcomes)if(outcome.status==='rejected')console.log(JSON.stringify({status:'error',message:outcome.reason.message}));
const pulls=outcomes[1].status==='fulfilled'?outcomes[1].value:null;
if(pulls){
 const query={dataType:'Casts',sourceID:1,startTime:pulls.fight.startTime,endTime:pulls.fight.startTime+90000,maxEvents:1000,maxPayloadBytes:500000,includeNames:true};
 await request('get_events','azaelle-opener-casts.json',{report,fightID:1,...query},()=>service.getEvents(report,query,options));
 const checks=[['eye-beam', 'Casts',198013],['abyssal-gaze','Casts',452497],['empowered-buff','Buffs',1271144]];
 const checked=await Promise.allSettled(checks.map(async([label,dataType,abilityID])=>{
  const query={dataType,...(dataType==='Buffs'?{targetID:1}:{sourceID:1}),abilityID,startTime:pulls.fight.startTime,endTime:pulls.fight.endTime,maxEvents:1000,maxPayloadBytes:500000,includeNames:true};
  return request('get_events',`azaelle-${label}-events.json`,{report,fightID:1,...query},()=>service.getEvents(report,query,options));
 }));
 for(const outcome of checked)if(outcome.status==='rejected')console.log(JSON.stringify({status:'error',message:outcome.reason.message}));
}
