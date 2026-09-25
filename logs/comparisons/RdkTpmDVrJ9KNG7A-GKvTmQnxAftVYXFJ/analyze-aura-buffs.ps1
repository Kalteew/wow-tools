$ErrorActionPreference='Stop'
$comparisonDir=$PSScriptRoot
$azaBuffs=(Get-Content -LiteralPath "$comparisonDir/azaelle-buffs.json" -Raw|ConvertFrom-Json).data.data.auras
$refBuffs=(Get-Content -LiteralPath "$comparisonDir/comparator-context-direct.json" -Raw|ConvertFrom-Json).reportData.report.buffs.data.auras
$allResults=@()
foreach($player in @('azaelle','comparator')) {
  $auraData=(Get-Content -LiteralPath "$comparisonDir/$player-aura-tick-events.json" -Raw|ConvertFrom-Json).reportData.report
  $ticks=@($auraData.PSObject.Properties|ForEach-Object {$_.Value.data})
  $rage=@((Get-Content -LiteralPath "$comparisonDir/$player-ragefire-events.json" -Raw|ConvertFrom-Json).reportData.report.events.data)
  $auras=if($player -eq 'azaelle'){$azaBuffs}else{$refBuffs}
  $buffs=@{}
  foreach($aura in $auras){$buffs[[int]$aura.guid]=$aura.name}
  $rows=@()
  foreach($set in @(@('ticks',$ticks),@('ragefire',$rage))) {
    $events=$set[1]
    $groups=@{}
    foreach($ev in $events){
      foreach($id in @($ev.buffs -split '\.'|Where-Object {$_})){
        if(!$groups.ContainsKey($id)){$groups[$id]=[System.Collections.Generic.List[object]]::new()}
        $groups[$id].Add($ev)
      }
    }
    foreach($id in $groups.Keys){
      $g=$groups[$id]
      $amount=($g|Measure-Object amount -Sum).Sum
      $crits=@($g|Where-Object hitType -eq 2)
      $rows+=[pscustomobject]@{phase=$set[0];id=[int]$id;name=$buffs[[int]$id];count=$g.Count;coverage=[math]::Round(100*$g.Count/$events.Count,2);amount=$amount;average=[math]::Round($amount/$g.Count,1);critRate=[math]::Round(100*$crits.Count/$g.Count,2)}
    }
  }
  $allResults += [pscustomobject]@{player=$player;tickCount=$ticks.Count;rageCount=$rage.Count;buffs=@($rows|Sort-Object phase,coverage -Descending)}
}
$allResults|ConvertTo-Json -Depth 7|Set-Content -LiteralPath "$comparisonDir/aura-buff-coverage.json" -Encoding utf8
foreach($p in $allResults){
  Write-Output $p.player
  $p.buffs|Where-Object {$_.name -match 'Exergy|Initiative|Metamorphosis|Potion|Well Fed|Demon Soul|Demonic Intensity|Unbound|Growing|Arcanoweave|Void|Ula|Strength|Roar|Hunt|Halazzi'}|Select-Object phase,name,coverage,average,critRate|Format-Table -AutoSize
}
