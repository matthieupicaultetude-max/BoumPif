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
Traverser le portail à pied ou en voiture. À la première visite, une indication
« Préparation de l’île… » apparaît pendant sa construction progressive. Le portail violet de retour est derrière
le point d’arrivée sur l’île. Aucune touche supplémentaire.

Seule la zone visitée est attachée à la scène : le quartier ne rend ni ne simule
l’île à distance, et inversement. L’île est construite à sa première visite,
par petits lots répartis sur plusieurs images. Son terrain est découpé en tuiles
pour permettre le masquage des parties hors champ. Les zones sont conservées en
mémoire et réutilisées aux visites suivantes, sans reconstruction. La distance
d’affichage est adaptée au quartier et à l’île.

L’île mesure environ 600 mètres de large. Sa **boucle de course sauvage**
alterne virages serrés, courbes rapides, bosses, creux et dénivelés irréguliers.
La ligne de départ/arrivée est en damier, devant le panneau « CIRCUIT SAUVAGE »,
un peu après l’arrivée du portail. Les balises rouge et blanc bordent la boucle.
C’est un parcours libre : pas encore de chronométrage, de classement ni d’adversaires.

Trois massifs regroupent **1 066 arbres** et deux villages totalisent **32 maisons**.
Les troncs et les bâtiments ont des collisions, avec un dégagement autour des routes.
La montée en spirale vers le volcan, le cratère, la lave, le panache de fumée,
les chemins de terre et le sentier côtier sont conservés.

L’asphalte et la terre des chemins sont appliqués directement au matériau du
terrain via un masque généré à la première visite. Il n’existe plus de maillage
de chaussée superposé : la route épouse exactement la surface physique, sans
intersections entre triangles ni scintillement aux croisements. Le masque donne
priorité à l’asphalte lorsque deux tracés se croisent. Les arbres et les balises
sont affichés en lots ; les massifs hors champ ou trop éloignés sont masqués.

Tomber dans l’eau ou dans la lave ramène à l’arrivée de la zone. Le passage
d’un portail emmène aussi la voiture, stationnée près de l’arrivée si l’on est à pied.
**R** réinitialise dans la zone actuelle. C’est une première version du décor,
avec des formes simples, sans intérieurs de maisons ni simulation d’eau.

## La Fonderie : arène de destruction derby

Prendre le **portail orange au sud du quartier**, à l’opposé de celui de l’île.
L’arène est construite à la première visite et mise en cache, comme l’île ;
seule la zone visitée est affichée et simulée. Le portail de retour se trouve
près du départ sud de l’arène.

Le terrain mesure environ **220 mètres de diamètre** avec **quatre emplacements
de départ** espacés et orientés vers le centre. Une cuvette vallonnée entoure
un plateau de choc central. Quatre rampes diagonales permettent de sauter dans
la cuvette ; huit conteneurs forment des chicanes. Seize caisses et huit fûts
physiques peuvent être projetés par une voiture.

Les rampes ont un tablier métallique strié et patiné, des bandes de danger,
des longerons, des traverses, des boulons et des supports contreventés. Les
conteneurs ont des nervures, des portes doubles, des charnières, des barres de
verrouillage, des pièces rouillées et des identifiants peints. Le sol conserve
sa surface physique continue, avec du grain, des traces de dérapage et des
taches d’huile appliqués dans son matériau.

Les barrières reçoivent des panneaux de béton, des joints, des fixations,
des bandes de sécurité et des piles de pneus solides. Quatre épaves de voitures,
quatre ateliers, les gradins et les tours de projecteurs complètent le décor.
Les petits détails statiques sont regroupés en MultiMesh pour limiter les appels
de rendu, et la construction reste répartie sur plusieurs images.

**R** remet la voiture, les caisses et les fûts au départ. Les véhicules restent pilotables
avec les commandes habituelles. Cette version prépare le terrain pour quatre
voitures : le multijoueur, les adversaires, les points de vie et la déformation
des carrosseries ne sont pas encore implémentés.

## Voiture de rallye

La voiture dispose d’une carrosserie biseautée, d’un habitacle incliné, d’un toit
contrasté, de phares, de feux arrière, d’une calandre, de rétroviseurs, de poignées,
de pare-chocs, d’un aileron et de sorties d’échappement. Les pneus sont cylindriques,
avec bande de roulement et jantes à branches ; ils tournent avec le déplacement,
et les roues avant braquent.

Quatre sondes de sol pilotent l’inclinaison de la caisse et les suspensions visuelles
indépendantes à ressorts amortis. La caisse accompagne les bosses et se stabilise
après l’atterrissage, avec du roulis en virage et du tangage à l’accélération/freinage.
La vitesse est influencée par la pente et l’adhérence par les appuis au sol.
Dans les airs, l’élan et la gravité déterminent la trajectoire : l’accélérateur
ne crée pas d’adhérence et le braquage est fortement réduit.

Le contrôleur utilise `CharacterBody3D` avec une collision de caisse simplifiée.
Les quatre roues et ressorts servent à l’animation et à la mesure des appuis ;
il ne s’agit pas d’une simulation rigide complète avec forces par roue.
Les jantes et les sculptures des pneus sont regroupées pour limiter les appels de rendu.

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

La conduite est arcade : accélération vive, braquage serré et mini-turbos.
Il n’y a pas encore de dégâts, de circulation ou de sauvegarde. Si une sortie est bloquée, le jeu essaie
l'autre côté du véhicule. La ville est délimitée par des murs.

## Validation

Depuis la racine du dépôt, avec Godot accessible dans le terminal :

```sh
godot --headless --path boum-pif --editor --import --quit
godot --headless --fixed-fps 60 --path boum-pif --script res://tests/smoke.gd
```

Le test vérifie les roues, les quatre appuis sur une rampe, l’inclinaison, le contact
des pneus avec la pente, les ressorts, le comportement aérien, le sol, la marche, l'entrée et la sortie de voiture, la conduite,
le freinage, le saut de drift, le contre-braquage, les deux niveaux de mini-turbo et leurs étincelles,
l’expiration du boost, les collisions avec les bâtiments et la limite de ville, et la réinitialisation.
Il teste aussi les portails dans les deux sens, les collisions de la montée, un trajet
physique complet en voiture jusqu’au cratère, un tour complet du circuit sauvage,
la couverture des tracés par le matériau de route et l’absence de chaussée superposée, et la récupération après une chute dans l’eau.
L’arène est aussi vérifiée : portails, quatre départs libres, charge vers le centre,
saut sur une rampe, enceinte, impact sur une caisse et réinitialisation des débris.
La qualité visuelle et les sensations de conduite restent à évaluer dans l’éditeur.
