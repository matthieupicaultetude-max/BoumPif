# BoumPif

Premier prototype de bac à sable 3D avec Godot 4, GDScript et rendu Compatibility.

## Jouer sur Windows

Ouvrir `boum-pif/project.godot` dans Godot 4.6 ou ultérieur, puis appuyer sur **F5**.
La scène principale est `scenes/main.tscn`. Le quartier et ses collisions sont créés par `scripts/main.gd`.

- ZQSD, WASD ou flèches : marcher / conduire.
- Souris : regarder autour de soi.
- E : monter dans la voiture orange à proximité, ou descendre une fois arrêté.
- Espace : sauter à pied ; en voiture, appuyer en braquant à partir de 29 km/h pour lancer un dérapage avec un petit saut, puis maintenir. À faible vitesse ou sans direction au déclenchement, Espace freine.
- R : remettre le personnage et la voiture au départ.
- Échap : libérer la souris ; clic dans le jeu : la capturer.

## Première zone : l’île du volcan

Depuis le quartier, suivre la route vers le nord (tout droit depuis le départ) :
le portail turquoise « ÎLE DU VOLCAN » se trouve avant le mur, au bout de la rue.
Traverser le portail à pied ou en voiture. Le portail violet de retour est derrière
le point d’arrivée sur l’île. Aucun chargement manuel ni touche supplémentaire.

L’île mesure environ 600 mètres de large et comprend une côte, du relief,
un volcan central avec cratère, lave et panache de fumée, une route goudronnée
en spirale jusqu’au sommet, deux villages de six maisons, des chemins de terre
vers les hameaux, un sentier côtier et un chemin autour du cratère.
Les bâtiments, le relief et les routes sont solides. Le véhicule utilise une
surface physique continue et un accrochage au sol pour les pentes.

Tomber dans l’eau ou dans la lave ramène à l’arrivée de la zone. Le passage
d’un portail emmène aussi la voiture, stationnée près de l’arrivée si l’on est à pied.
**R** réinitialise dans la zone actuelle. C’est une première version du décor,
avec des formes simples, sans intérieurs de maisons ni simulation d’eau.

## Dérapage façon kart

Le système s'inspire du dérapage manuel de Mario Kart Wii, avec des réglages propres à BoumPif.
Maintenir l'accélérateur et Espace pendant un virage. Le côté du drift est fixé au déclenchement :
braquer vers ce côté resserre la courbe, contre-braquer l'élargit sans inverser le drift.
Le turbo charge au sol à vitesse suffisante ; braquer vers l'intérieur charge plus vite.

- Étincelles **bleues** : mini-turbo prêt, relâcher Espace pour 0,65 s de boost.
- Étincelles **orange** : super mini-turbo prêt, relâcher pour 1,3 s de boost.
- Un relâchement trop tôt ne donne aucun turbo. Un choc ou R annule la charge et le boost.
- Les pneus arrière dégagent une fumée grise qui se dissipe derrière la voiture pendant les dérapages au sol.
- Les étincelles bleues/orange indiquent la charge ; deux gerbes dorées s'allument derrière la voiture pendant le boost.
- L'inclinaison de la carrosserie et l'indication à l'écran signalent aussi le drift.

La conduite est arcade : accélération vive, braquage serré et mini-turbos, avec une voiture qui reste droite : pas encore de suspension,
de dégâts, de circulation ou de sauvegarde. Si une sortie est bloquée, le jeu essaie
l'autre côté du véhicule. La ville est délimitée par des murs.

## Validation

Depuis la racine du dépôt, avec Godot accessible dans le terminal :

```sh
godot --headless --path boum-pif --editor --import --quit
godot --headless --fixed-fps 60 --path boum-pif --script res://tests/smoke.gd
```

Le test vérifie le sol, la marche, l'entrée et la sortie de voiture, la conduite,
le freinage, le saut de drift, le contre-braquage, les deux niveaux de mini-turbo et leurs étincelles,
l’expiration du boost, les collisions avec les bâtiments et la limite de ville, et la réinitialisation.
Il teste aussi les portails dans les deux sens, les collisions de la montée, un trajet
physique complet en voiture jusqu’au cratère et la récupération après une chute dans l’eau.
La qualité visuelle et les sensations de conduite restent à évaluer dans l’éditeur.
