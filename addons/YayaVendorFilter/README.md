# Yaya Vendor Filter

Filtre l'interface vendeur de Blizzard pour masquer et compacter :

- les recettes deja connues ;
- les transmogrifications deja collectionnees ;
- les jouets, montures, mascottes et objets heritages deja obtenus.
- les objets reserves a une autre classe, faction ou race ;
- les armures et armes que la classe ne peut pas utiliser ;
- les recettes, equipements et objets de connaissance d'un metier que le
  personnage ne possede pas.

Une recette reste affichee si le personnage possede le bon metier mais n'a pas
encore le niveau de competence requis, meme si sa fabrication ne peut pas etre
equipee par sa classe. Les restrictions temporaires de niveau, specialisation
ou reputation ne sont pas masquees.

Le bouton `Masquer inutiles` dans la fenetre du vendeur active ou desactive le
filtre. Le choix est conserve pour le compte.

Commande : `/yvf` pour basculer le filtre, `/yvf on` ou `/yvf off`.

Limites :

- le decor Housing n'est pas filtre ;
- l'interface vendeur personnalisee de TSM n'est pas modifiee : utiliser son
  bouton permettant d'afficher l'interface Blizzard.
