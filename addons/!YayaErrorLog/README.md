# Yaya Error Log

Journal persistant des erreurs Lua et des actions bloquees, pour identifier
l'addon **et la ligne** derriere le popup qui propose de desactiver un addon.

## Pourquoi

Le client ne laisse rien a lire apres coup :

- `scriptErrors` vaut 0 par defaut, donc le texte des erreurs Lua n'est jamais
  affiche ;
- `Logs/FrameXML.log` ne consigne que les erreurs de *chargement*, pas celles
  d'execution ;
- le popup `ADDON_ACTION_FORBIDDEN` nomme l'addon fautif, mais le nom de la
  fonction protegee et la pile d'appel disparaissent avec la fenetre.

Cet addon capture les trois informations manquantes : l'addon incrimine, la
fonction refusee, et la pile d'appel — c'est elle qui nomme le fichier et la
ligne responsables.

## Le prefixe `!` dans le nom du dossier

WoW charge les addons par ordre alphabetique, et un gestionnaire d'erreurs
n'attrape que ce qui suit son installation. Sans le `!`, cet addon se
chargerait apres la plupart des autres et manquerait les fautes commises
pendant leur chunk et dans leur handler `ADDON_LOADED`. C'est la convention de
`!BugGrabber`, pour la meme raison. Le nom du fichier `.toc` doit porter le
meme `!` que le dossier.

## Ce qui est capture

| Source | Contenu |
| --- | --- |
| `ADDON_ACTION_FORBIDDEN` | addon, fonction protegee, pile, zone, etat de combat |
| `ADDON_ACTION_BLOCKED` | idem — precede souvent la faute fatale |
| Erreurs Lua | message, pile, zone, etat de combat |
| `PLAYER_LOGIN` | une entree par session, pour corroborer un incident qui revient a chaque connexion |

Le gestionnaire d'erreurs **enveloppe** celui deja en place au lieu de le
remplacer : un BugSack eventuel et le dialogue du client continuent de
fonctionner. La collecte du contexte est isolee source par source, car une faute
a l'interieur du gestionnaire le rendrait inutilisable pour toute la session.

Les frames de cet addon sont ecartees de la ligne fautive retenue : c'est son
gestionnaire d'erreurs qui ouvre la pile, et sans ce filtrage chaque incident lui
serait impute. La pile complete reste enregistree telle quelle.

Les incidents sont regroupes par signature (type, message normalise, premiere
ligne d'addon dans la pile). Seuls les trois premiers exemplaires d'une
signature conservent leur pile complete ; au-dela, seul le compteur augmente.
Sans ce regroupement, une faute dans un ticker 0,5 s noierait le journal en une
minute.

## Commandes

| Commande | Effet |
| --- | --- |
| `/yerr` | resume : nombre d'incidents et les huit plus frequents |
| `/yerr dump` | fenetre copiable avec le recapitulatif et les piles |
| `/yerr probe` | teste pourquoi un `RegisterEvent` est refuse : aspect interdit sur la frame, ou evenement restreint |
| `/yerr test` | declenche une erreur volontaire, pour verifier que la capture fonctionne |
| `/yerr clear` | vide le journal |

`/yerr test` compte : un journal vide ne permet pas, seul, de distinguer
« aucune faute » de « instrumentation inoperante ».

`/yerr probe` tente reellement les enregistrements, donc **il declenche lui-meme
le dialogue de desactivation** pour tout evenement refuse. C'est le prix du test,
et c'est ainsi qu'a ete identifie `COMBAT_LOG_EVENT_UNFILTERED`. Le test de la
frame, lui, passe par `IsEventRegistered` et ne modifie rien.

## Relecture depuis le disque

Le journal vit dans `YayaErrorLogDB`, donc dans
`WTF/Account/<compte>/SavedVariables/!YayaErrorLog.lua`.

**WoW n'ecrit ce fichier qu'au `/reload` ou a la deconnexion.** Reproduire un
incident puis lire le fichier sans recharger l'interface ne donne rien.

## Limites

- Les fautes anterieures au chargement de cet addon lui echappent, `!` ou non.
- Une pile qui traverse le dispatcher d'evenements du client peut s'arreter
  avant le code fautif ; le recapitulatif reste alors le seul indice.
- `YayaCore` est optionnel : son `RingBuffer` est utilise s'il est charge, sinon
  un repli equivalent prend le relais, pour que cet addon reste utilisable dans
  un profil minimal servant a isoler un addon suspect.
