import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {WclService,loadConfig,errorToJson} from 'file:///C:/Users/Yaya/source/tools/warcraftlogs-mcp-fork/dist/index.mjs';

const report='GKvTmQnxAftVYXFJ';
const dir='C:/Users/Yaya/source/tools/wow-tools/logs/comparisons/RdkTpmDVrJ9KNG7A-GKvTmQnxAftVYXFJ';
const service=WclService.fromConfig(loadConfig());
const options={fight:8,accessMode:'public'};
const originalJobs=[
 ['get_report','comparator-report.json',{report},()=>service.getReport(report,{accessMode:'public'})],
 ['get_player_analysis_context','comparator-context.json',{report,fightID:8,player:'Омгпвпкритт'},()=>service.getPlayerAnalysisContext(report,'Омгпвпкритт',{...options,maxEntries:150,maxPayloadBytes:1500000})],
 ['get_report_rankings','comparator-rankings.json',{report,fightID:8,playerMetric:'dps'},()=>service.getReportRankings(report,{...options,playerMetric:'dps'})],
 ['list_dungeon_pulls','comparator-pulls.json',{report,fightID:8},()=>service.listDungeonPulls(report,options)],
];
const direct=(query)=>service.client.query('https://www.warcraftlogs.com',query,{code:report},{mode:'public'});
const contextJobs=[
['get_player_context_direct','comparator-context-direct.json',{report,fightID:8,playerID:436},()=>direct(`query DirectContext($code:String!){reportData{report(code:$code){damage:table(dataType:DamageDone fightIDs:[8] sourceID:436) casts:table(dataType:Casts fightIDs:[8] sourceID:436) buffs:table(dataType:Buffs fightIDs:[8] targetID:436) deaths:table(dataType:Deaths fightIDs:[8] sourceID:436) combatant:events(dataType:CombatantInfo fightIDs:[8] sourceID:436 startTime:6764714 endTime:8467919 limit:100 useAbilityIDs:false useActorIDs:false){data nextPageTimestamp} fights(fightIDs:[8]){id talentImportCode(actorID:436)}}}}`)],
['get_report_rankings_direct','comparator-rankings-direct.json',{report,fightID:8},()=>direct(`query DirectRankings($code:String!){reportData{report(code:$code){rankings(fightIDs:[8] playerMetric:dps timeframe:Historical)}}}`)],
['list_dungeon_pulls_direct','comparator-pulls-direct.json',{report,fightID:8},()=>direct(`query DirectPulls($code:String!){reportData{report(code:$code){fights(fightIDs:[8]){id dungeonPulls{id name startTime endTime encounterID kill enemyNPCs{id gameID minimumInstanceID maximumInstanceID minimumInstanceGroupID maximumInstanceGroupID}}}}}}`)],
];
const jobs=[['get_burst_events_direct','comparator-burst-events.json',{report,fightID:8,sourceID:436,abilityIDs:[370965,198013,452497,1271144]},()=>direct(`query DirectBurst($code:String!){reportData{report(code:$code){hunt:events(dataType:Casts fightIDs:[8] sourceID:436 abilityID:370965 startTime:6764714 endTime:8467919 limit:1000 useAbilityIDs:false useActorIDs:false){data nextPageTimestamp} eye:events(dataType:Casts fightIDs:[8] sourceID:436 abilityID:198013 startTime:6764714 endTime:8467919 limit:1000 useAbilityIDs:false useActorIDs:false){data nextPageTimestamp} abyssal:events(dataType:Casts fightIDs:[8] sourceID:436 abilityID:452497 startTime:6764714 endTime:8467919 limit:1000 useAbilityIDs:false useActorIDs:false){data nextPageTimestamp} empowered:events(dataType:Buffs fightIDs:[8] targetID:436 abilityID:1271144 startTime:6764714 endTime:8467919 limit:1000 useAbilityIDs:false useActorIDs:false){data nextPageTimestamp}}}}`)]];
fs.mkdirSync(dir,{recursive:true});
function record(tool,args,status,summary,errorCode=''){
 const argv=['-NoProfile','-File','C:/Users/Yaya/.codex/skills/warcraftlogs-core/scripts/record_wcl_request.ps1','-ReportCode',report,'-Tool',tool,'-ArgsJson',JSON.stringify(args),'-Status',status,'-SummaryJson',JSON.stringify(summary),'-LogsRoot','C:/Users/Yaya/source/tools/wow-tools/logs'];
 if(errorCode)argv.push('-ErrorCode',errorCode);
 const logged=spawnSync('powershell',argv,{encoding:'utf8',windowsHide:true});
 if(logged.status!==0)throw Error('History recording failed: '+logged.stderr);
}
const settled=await Promise.allSettled(jobs.map(async([tool,file,args,fn])=>{
 const target=path.join(dir,file);
 if(fs.existsSync(target)){console.log(JSON.stringify({tool,cached:true,file}));return;}
 try{
  const result=await fn();
  fs.writeFileSync(target,JSON.stringify(result,null,2));
  record(tool,args,'success',{file,bytes:fs.statSync(target).size});
  console.log(JSON.stringify({tool,status:'success',file,bytes:fs.statSync(target).size}));
 }catch(e){
  const error=errorToJson(e);
  record(tool,args,'error',error,error.code);
  console.log(JSON.stringify({tool,status:'error',...error}));
 }
}));
for(const x of settled)if(x.status==='rejected')console.log(JSON.stringify({status:'error',message:x.reason.message}));
