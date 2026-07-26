# Yaya Frame

Frame commune partagee par les addons Yaya.

- possede la position, le fond, le deplacement et la hauteur globale ;
- masque toute la frame en combat quand `YayaFrameAPI:SetHideInCombat(true)` est active ;
- accueille des sections enregistrees par `YayaSessionTracker` et `YayaWeeklyTracker`.

La position est stockee dans `YayaFrameDB`. `/yst reset` et `/ywt reset` la reinitialisent egalement.
