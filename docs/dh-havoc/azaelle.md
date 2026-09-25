# Azaelle — état local des logs

## Source principale disponible

- Découverte complète : [`azaelle-discovery.json`](../../data/dh-havoc/azaelle-discovery.json), produite par [`discover-azaelle-reports.mjs`](../../scripts/dh-havoc/discover-azaelle-reports.mjs).
- La requête exacte `Azåelle / Hyjal / EU` renvoie **55 rapports**, contenant **158 fights M+** (**125 terminés**, **33 échoués/incomplets**). **16 rapports** ne possèdent pas encore de snapshot brut local ; ils sont listés dans l’inventaire.
- Report : [RdkTpmDVrJ9KNG7A](https://www.warcraftlogs.com/reports/RdkTpmDVrJ9KNG7A), fight 1.
- Contenu : Murder Row +16, M+ terminé en 29:41, Fel-Scarred, patch 12.1.
- Fiche locale : `logs/reports/RdkTpmDVrJ9KNG7A-fight-1.json`.
- Preuve de comparaison : `logs/comparisons/RdkTpmDVrJ9KNG7A-GKvTmQnxAftVYXFJ/browser-evidence.json`.
- Opener détaillé : `logs/comparisons/RdkTpmDVrJ9KNG7A-GKvTmQnxAftVYXFJ/azaelle-opener-casts.json`.
- Analyse des fenêtres : `logs/comparisons/RdkTpmDVrJ9KNG7A-GKvTmQnxAftVYXFJ/azaelle-analysis.json`.

## Faits observés

- Azaelle : 189 666 DPS, 19 380 HPS, 2 morts, 12 interrupts.
- Ilvl affiché : 315 ; 4 pièces de set ; Crit 1181, Maîtrise 929, Hâte 185, Polyvalence 478.
- Casts : Eye Beam 51, Abyssal Gaze 16, Essence Break 37, Death Sweep 153, Metamorphosis 12, The Hunt 22, Immolation Aura 55.
- Buffs : Metamorphosis 40,54 %, Exergy 80,62 %, Initiative 29,99 %, Well Fed 41,82 %, Empowered Eye Beam 12,68 %.
- Morts : environ 11:50 et 25:00. Les deux fenêtres doivent être retirées du jugement de rotation avant de conclure.
- Premier opener observé : Immolation Aura à 24,344/25,404 ; Eye Beam 28,242 ; Annihilation 29,923 ; Essence Break 30,879 ; The Hunt 32,316 ; Death Sweep 32,789/33,622 ; Meta 36,130 ; Death Sweep 38,370 ; Annihilation 39,436 ; Abyssal Gaze 42,466.
- 22 applications d’Empowered Eye Beam ont été relevées ; 9 ont démarré un rayon dans la fenêtre et 13 ont expiré sans début de rayon. C’est une piste de séquencement, pas une perte DPS chiffrée.

## Comparaison locale

Le comparateur est un autre joueur, autre clé (+17), autre date, autre groupe, autre ilvl et autre route. Le DPS de table était 198 743 pour Azaelle contre 316 104 pour le comparateur. Cette différence ne peut pas être attribuée à un seul bouton.

Les percentiles WCL report-specific ne sont pas disponibles dans la capture historique : population vide côté MCP, tandis que l’UI affiche des valeurs 100 incohérentes. Ils sont donc stockés comme `null`/preuve UI séparée, jamais comme benchmark fiable.

## Diagnostic prudent

1. Les morts sont une priorité de survie et d’uptime.
2. La piste gameplay la plus mesurable est la consommation des fenêtres Empowered Eye Beam/Abyssal Gaze.
3. Il faut ensuite vérifier Essence Break → spenders, procs Demonsurge, cibles de Burning Wound et explosion Ragefire.
4. Aucun log Aldrachi local n’a été identifié : la branche Aldrachi reste une grille de validation, pas une conclusion sur Azaelle.

## Pourquoi la première découverte était incomplète

L’ancien index ne parcourait que les JSON déjà présents dans `logs/reports`, et l’analyse Aura ne portait que sur les snapshots détaillés disponibles. Les synchronisations précédentes utilisaient aussi une fenêtre `since` : elles ne constituaient donc pas une pagination historique complète. La découverte officielle par `recentReports` est désormais séparée de l’index des données téléchargées.

## Progression Aura / Ragefire

Une analyse longitudinale est conservée dans [`azaelle-aura-progression.json`](../../logs/comparisons/azaelle-aura-progression.json). Les 9 fichiers bruts exploitables se dédupliquent en **5 runs distincts**.

- Avec quasiment les mêmes stats, le hit moyen de **Ragefire** varie de **74,2 k à 101,5 k** : environ **37 % d’écart**.
- La moyenne d’impact de l’**Aura composite** varie de **11,85 k à 14,15 k** : environ **19 % d’écart**.
- Le passage Murder Row +15 → +16 monte de 12,6 % sur Ragefire, mais ce n’est pas une mesure de scaling : Crit ne gagne qu’1 point, Maîtrise baisse de 40 et Polyvalence augmente de 62 ; la route, les packs, les buffs et les morts changent aussi.

Conclusion : ces données montrent surtout l’effet du contexte de pull, du nombre de cibles et des buffs. Elles ne démontrent pas encore combien 1 point de Crit ou de Maîtrise ajoute à Ragefire. Il faudrait plusieurs logs du même donjon avec des packs comparables et des paliers de stats réellement différents.
