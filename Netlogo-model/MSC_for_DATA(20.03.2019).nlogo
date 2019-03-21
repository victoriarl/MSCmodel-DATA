;; MODELLING OF RAT STEM CELLS/CARDIOMYOCYTES/ENDOTHELIAL CELLS BEHAVIOUR
;; IN A 3D PRINTED BIOMATERIAL

;; Patches are heart tissue where a biodevice made of cells and collagen are placed,
;; their attributes are damage, inflammation and capacity.
;; Damage is a boolean atribute which value is 1 for tissue areas
;; that have died due to ischemia
;; Inflammation is a reaction linked to myocardial infarction and
;; is one of the symptoms that is reduced by MSCs. Its value is
;; between 0 and 1.
;; Capacity is the number of cells that can occupy one patch.
patches-own [ damage inflammation capacity ]

;; CELL TYPES
;; Mesenchymal Stem Cells (MSCs) have 5 attributes, which are linked
;; to the differentiation capability of this cell type.
;; - prob-diff-cardio indicates the daily probability of a MSC to become
;;   a cardiomyocyte depending on his surroundings.
;; - prob-diff-endo indicates the daily probability of a MSC to become
;;   an endothelial cell depending on his surroundings.
;; - diff-time-count indicates how many days a MSC has been into
;;   differentiation process.
;; - diff-time is the time that the differentiation process is meant to
;;   last for a MSC.
;; - prox-type saves the type to which a cell has decided to differentiate
;;   once the differentiation process begins.
breed [MSCs MSC] MSCs-own [ prob-diff-cardio prob-diff-endo
                            diff-time-count diff-time prox-type]
;; Cardiomyocytes have 2 attributes.
;; - apop-prob indicates the probability for a cardiomyocyte to die on a
;;   given day.
;; - pc-per-cardio gives each cardiomyocyte a value to contribute to the
;;   prob-diff-cardio of a nearby MSC, it can vary depending on the
;;   location of a cardiomyocyte along the tissue.
breed [cardiomyocytes cardiomyocyte] cardiomyocytes-own [ apop-prob pc-per-cardio ]
;; Endothelial cells have only 1 attribute.
;; - apop-prob indicates the probability for an endothelial cell to die
;; on a given day.
breed [endothelials endothelial] endothelials-own [ apop-prob pc-per-endo ]

;; GLOBAL VARIABLES
globals [
  apoptosis-rnd ;; Random number to evaluate apoptosis
  collagen-concentration ;; Concentration of the collagen where the cells are suspended
  day ;; Constant
  dead-cardio ;; Dead cardiomyocytes counter
  dead-endo ;; Dead endothelial cells counter
  directory ;; Where to store results
  new-MSCs ;; New MSCs counter (from division)
  new-endothelials ;; New endothelial cells counter (from division)
  mean-inflammation ;; Saves the measure of mean inflammation
  mean-pc-per-cardio ;; Saves the measure of mean pc-per-cardio
  mean-pc-per-cardio-scar ;; Saves the measure of mean pc-per-cardio of scar
  mean-pc-per-endo ;; Saves measure of mean pc-per-endo
  MSC-to-cardio ;; Counter of MSC differentiated into cardiomyoctes
  MSC-to-endo ;; Counter of MSC differentiated into endothelial cells
]

;; When the "Setup" button is pressed
to Setup
  clear-all

  ;; Set shape of each cell type
  set-default-shape MSCs "circle"
  set-default-shape cardiomyocytes "circle"
  set-default-shape endothelials "circle"
  set day 1 ;; Constant value

  ;; Initialize all counters on 0
  set dead-cardio 0
  set dead-endo 0
  set MSC-to-cardio 0
  set MSC-to-endo 0
  set new-MSCs 0
  set new-endothelials 0

  set directory "/home/victoria/ModelosNL/Prueba1_" ;; Direction to store output images
  reset-ticks
  reset-timer

  ;; Load picture with the scaffold channels' pattern
  import-pcolors "channels.png"

  ;; Set capacity of each patch
  ask patches [ set capacity  layers ]


  ;; If distribution is chosen to be "mixed"
  if distribution = "mixed" [
    ;; To simulate the fact that cells can be on top of each other the cells are created
    ;; in batches of one third of the total initial number of cells. In each repetition
    ;; a number of "Num-cells" turtles is created and by thirds they are afterwards assigned
    ;; a breed. The maximum number of cells that can occupate the same place is 3, this way
    ;; it can be simulated that cells are distributed in 3 layers.
    repeat 3 [
      ask n-of Num-cells patches with [capacity	> 0 and pcolor = white ] [ sprout 1 set capacity capacity - 1 ]
      ask n-of ( Num-cells / 3 ) turtles with [ breed = turtles ] [
        ;; Endothelial cells are blue
        set breed endothelials set color blue set heading 0 set apop-prob (0.01 * day) ]
      ask n-of ( Num-cells / 3 ) turtles with [ breed = turtles ]	[
        ;; Cardiomyocytes are red
        set breed cardiomyocytes set color red set heading 0 set apop-prob (0.01 * day) ]
      ask n-of ( Num-cells / 3 ) turtles with [ breed = turtles ] [
        ;; MSCs are white
        set breed MSCs set color white set heading 0 set diff-time 0 set diff-time-count 0 ]
    ]
  ]

  ;; If distribution is chosen to be "cross"
  if distribution = "pattern" [
    ;; The pattern is copied from an image
    import-pcolors "Cross.png"
    ;; Cells are also created in batches to simulate layers, the difference here is that
    ;; endothelial cells can only be created in a specific cross-shaped area
    repeat 3 [
      ask n-of ( Num-cells / 3 ) patches with [ pcolor = black and capacity > 0 ] 	[
          sprout-endothelials 1 [ set color blue set heading 0 	set apop-prob (0.01 * day) ] set capacity capacity - 1 ]
      ;; The same process of the "mixed" distribution is followed for cardiomyocytes and MSCs
      ask n-of ( 2 *( Num-cells / 3 ) ) patches with [ pcolor = white and capacity > 0 ] [
          sprout 1 set capacity capacity - 1]
      ask n-of ( Num-cells / 3 ) turtles with [ breed = turtles ] [ set breed cardiomyocytes 	set color red set heading 0 set apop-prob (0.01 * day) ]
      ask n-of ( Num-cells / 3 ) turtles with [ breed = turtles ] [ set breed MSCs set color	white set heading 0 set diff-time 0 set diff-time-count 0 ] ]
 ]

  ;; Copy capillars pattern from an image to simulate vascularized
  ;; living tissue
  import-pcolors "capillars.png"
  ask patches [
     if-else shade-of? white pcolor [
      set pcolor 13 ] ;; Asign dark red color to the healthy myocardyum tissue
    [ set pcolor 103 ] ;; Asign dark blue color to the healthy capillars
    set inflammation 0 ;; Initialize all tissue with an inflammation of 0
  ]

  ;; Create a circular damaged area (dead tissue) which size is determined by the slider
  ;; scar-size
  ask patch 0 0 [
    ask patches in-radius ( max-pxcor * ( scar-size / 100 ) ) [
      ;; Set damaged tissue color to be a lighter shadow of red or blue and set
      ;; inflammation to its maximum (1) at the beginning of the simulation
      set damage 1 set pcolor pcolor + 6
      if-else inflammation-dist = "uniform" [ set inflammation 1 ]
      [ set inflammation ( -1 / ( max-pxcor * ( scar-size / 100 ) ) ) * ( distancexy 0 0 ) + 1 ]
      if shade-of? red pcolor [ set pcolor 5 * inflammation + 14 ]
      if shade-of? blue pcolor [ set pcolor 5 * inflammation + 104 ]
    ]
  ]

  ;; Depending on the "min-pc-cardio" the value of a cardiomyocyte for the differentiation
  ;; decision process of a MSC is determined, taking into account that the neighborhood
  ;; size of a MSC is 86 and that the sum of all the neighboring cells can't be greater
  ask cardiomyocytes [ set pc-per-cardio ( min-pc-cardio / 86 ) ] ;; Size of a MSC's neighborhood = 86
  ask endothelials [ set pc-per-endo ( min-pc-endo / 86 ) ]
  ask patches with [ damage = 1 ] [
    ask cardiomyocytes-here [ set pc-per-cardio 2 * pc-per-cardio ]
    ask endothelials-here [ set pc-per-endo 2 * pc-per-endo ]
    ]

end

to update-view
  if view = "all" [
    ask turtles [ set hidden? false ]
  ]
  if view = "layer 1" [
    ask turtles [ show-turtle ]
    ask turtles with [ who > Num-cells ] [ hide-turtle ]
  ]
  if view = "layer 2" [
    ask turtles [ show-turtle ]
    ask turtles with [ ( who <= Num-cells ) or ( who >= ( 2 * Num-cells ) ) ] [ hide-turtle ]
  ]
  if view = "layer 3" [
    ask turtles [ show-turtle ]
    ask turtles with [ who < ( 2 * Num-cells ) ] [ hide-turtle ]
  ]
end

to Go

  check-inflammation
  set mean-inflammation mean [ inflammation ] of patches with [ damage = 1 ]
  apoptosis
  set-diff-probability
  decide-differentiation
  ask cardiomyocytes [
    set pc-per-cardio (max-pc-cardio / 86 ) * (1 - [ inflammation ] of patch-here ) ]
  ask endothelials [
    set pc-per-endo (max-pc-endo / 86 ) * (1 - [ inflammation ] of patch-here ) ]
  divide
  migrate

  ;; For plotting

  set mean-pc-per-cardio mean [ pc-per-cardio ] of cardiomyocytes with [ damage = 0 ]
  set mean-pc-per-cardio-scar mean [ pc-per-cardio ] of cardiomyocytes with [ damage = 1 ]
  set mean-pc-per-endo mean [ pc-per-endo ] of endothelials with [ damage = 1 ]

  ;; Save PNG capture of the environment on every tick
  ;; export-view (word directory ticks ".PNG")

  ;; Save cell count on every tick
  ;; file-open "/home/victoria/ModelosNL/Prueba1.txt"
   ;; file-write (count MSCs) file-write (count cardiomyocytes)
   ;; file-write (count endothelials) file-write (timer)
  ;; file-close

  tick
end

;; MSC help in the reduction of inflammation and formation of scar
to check-inflammation
  ask patches with [ inflammation > 0 and any? MSCs-here ] [
    ask patches in-radius 6 with [ inflammation > 0 ] [
    set inflammation inflammation - 0.01
      if shade-of? red pcolor [ set pcolor 5 * inflammation + 14 ]
      if shade-of? blue pcolor [ set pcolor 5 * inflammation + 104 ]
    ]
  ]
end

;; Cells have a probability to die due to apoptosis
to apoptosis
  ;; For each cardiomyocyte and endothelial cell: if the random number "apoptosis-rnd" is
  ;; smaller than the pre-defined apoptosis probability, the cell dies. Counters are
  ;; updated everytime a cell dies
  ask cardiomyocytes
  [ set apoptosis-rnd random 10000 / 10000
    if apoptosis-rnd <= apop-prob [ set dead-cardio dead-cardio + 1 die ]
  ]
  ask endothelials
  [ set apoptosis-rnd random 10000 / 10000
    if apoptosis-rnd <= apop-prob [ set dead-endo dead-endo + 1 die ]
  ]
  ask cardiomyocytes [ set apop-prob 0.01 * [inflammation] of patch-here ]
  ask endothelials [ set apop-prob 0.01 * [inflammation] of patch-here ]
end

;; Determine differentiation probability of each MSC depending on its neighboring cells
to set-diff-probability
  ask MSCs [
    set prob-diff-cardio sum [ pc-per-cardio ] of cardiomyocytes in-radius 3
    set prob-diff-endo sum [ pc-per-endo ] of endothelials in-radius 3 ]
end

;; Determine if any MSC will differentiate depending on its differentiation probability
to decide-differentiation
  let diff-rnd random 100000 / 100000
  ;; Ask all MSCs which aren't into differentiation process
  ask MSCs with [ diff-time-count = 0 ] [
    ;; For each MSC: depending on the value of the random number "diff-rnd", the MSC starts
    ;; the differentiation process to cardiomyocyte or endothelial cell, or remains a MSC
    ;;  _____________________________________________
    ;; |                   |            |            |
    ;; 0                 p-d-c        p-d-e          1
    if-else diff-rnd < prob-diff-cardio
    [ set diff-time-count 1 set prox-type 0 ]
    [ if diff-rnd > prob-diff-cardio and diff-rnd < (prob-diff-endo + prob-diff-cardio)
      [ set diff-time-count 1 set prox-type 1 ]
    ]
  ]
  count-diff-time
end

;; Count the days that a MSC has been in differentiation process
to count-diff-time
  ask MSCs with [ diff-time-count > 0 ] [
    set diff-time round random-normal 16 3
    ifelse diff-time-count < diff-time
    [ set diff-time-count diff-time-count + 1
    ]
    [ if-else prox-type = 0
      [ set breed cardiomyocytes set color red + 2 set MSC-to-cardio MSC-to-cardio + 1]
      [ set breed endothelials set color blue + 2 set MSC-to-endo MSC-to-endo + 1]
    ]
  ]
end

;; Divide MSC and endothelial cells
to divide
  let div-rnd-MSC random 100000 / 100000
  ask n-of ( count MSCs * 0.1 ) MSCs-on patches with [ damage = 1 ] [
    if ( 1 - [ inflammation ] of patch-here < div-rnd-MSC ) and ( count turtles-on one-of neighbors4 < layers ) [
      ask one-of neighbors4 with [ count turtles-here < layers ] [
        sprout-MSCs 1 [ set color white ] set new-MSCs new-MSCs + 1]
    ]
  ]
  let div-rnd-endo random 100000 / 100000
    ask n-of ( count endothelials * 0.02 ) endothelials-on patches with [ damage = 1 and shade-of? blue pcolor ] [
    if ( 1 - [ inflammation ] of patch-here < div-rnd-endo ) and ( count turtles-on one-of neighbors4 < layers ) [
      ask one-of neighbors4 with [ count turtles-here < layers ] [
        sprout-endothelials 1 [ set color blue ] set new-endothelials new-endothelials + 1 ]
    ]
  ]
end

;;
to migrate
  ask  turtles with [ breed != endothelials ] [
    let diff-x random (5 - -5 + 1) + -5
    let diff-y random (5 - -5 + 1) + -5
    if abs ( xcor + diff-x ) <= max-pxcor and  abs ( ycor + diff-y ) <= max-pycor [
      if count turtles-on patch-at  diff-x diff-y < layers [
        setxy ( xcor + diff-x ) ( ycor + diff-y ) ] ]
  ]
  ask endothelials with [ count endothelials-on neighbors < 1 ] [
    ifelse shade-of? red pcolor [
      face min-one-of patches with [ shade-of? blue pcolor ] [ distance myself ]
      forward 3 ]
    [ face min-one-of endothelials [ distance myself ]
      forward 3]
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
16
12
811
808
-1
-1
1.403
1
10
1
1
1
0
0
0
1
-280
280
-280
280
1
1
1
ticks
30.0

BUTTON
837
385
901
418
NIL
Setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
914
385
977
418
Go
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
835
57
1094
90
Num-cells
Num-cells
2500
7500
2500.0
1000
1
NIL
HORIZONTAL

MONITOR
837
468
915
513
NIL
count MSCs
17
1
11

MONITOR
837
522
971
567
NIL
count cardiomyocytes
17
1
11

MONITOR
838
579
951
624
NIL
count endothelials
17
1
11

MONITOR
985
522
1064
567
NIL
dead-cardio
17
1
11

MONITOR
964
579
1037
624
NIL
dead-endo
17
1
11

MONITOR
929
468
1021
513
NIL
MSC-to-cardio
17
1
11

MONITOR
1036
469
1122
514
NIL
MSC-to-endo
17
1
11

PLOT
1298
16
1894
373
MSCs
NIL
NIL
0.0
90.0
0.0
75000.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count MSCs"
"pen-1" 1.0 0 -7500403 true "" "plot count endothelials"
"pen-2" 1.0 0 -2674135 true "" "plot count cardiomyocytes"

PLOT
1299
603
1600
819
Apoptosis probability cardiomyocytes
NIL
NIL
0.0
30.0
0.0
0.01
false
false
"" ""
PENS
"plot-apop-prob" 1.0 0 -16777216 true "" "plot mean [apop-prob] of cardiomyocytes"

SLIDER
835
284
999
317
scar-size
scar-size
0
100
75.0
5
1
NIL
HORIZONTAL

CHOOSER
835
96
998
141
distribution
distribution
"mixed" "pattern"
0

PLOT
1298
383
1600
600
Inflammation
NIL
NIL
0.0
30.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean-inflammation "

PLOT
1609
383
1894
598
MSC diifferentiation probability 
NIL
NIL
0.0
10.0
0.0
0.008
true
false
"" ""
PENS
"cardio-scar" 1.0 0 -16777216 true "" "plot mean-pc-per-cardio-scar"
"endo" 1.0 0 -7500403 true "" "plot mean-pc-per-endo"
"cardio-healthy" 1.0 0 -2674135 true "" "plot mean-pc-per-cardio"

CHOOSER
839
682
977
727
view
view
"all" "layer 1" "layer 2" "layer 3"
3

BUTTON
985
682
1105
727
NIL
update-view
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
835
149
914
209
min-pc-cardio
0.1
1
0
Number

INPUTBOX
923
149
998
209
min-pc-endo
0.05
1
0
Number

INPUTBOX
835
215
914
275
max-pc-cardio
0.8
1
0
Number

INPUTBOX
922
215
999
275
max-pc-endo
0.4
1
0
Number

MONITOR
1136
469
1206
514
new MSCs
new-MSCs
17
1
11

MONITOR
1051
579
1156
624
new endothelials
new-endothelials
17
1
11

TEXTBOX
835
24
985
46
Setup
18
0.0
1

TEXTBOX
837
432
987
454
Monitors
18
0.0
1

TEXTBOX
839
643
989
665
View\n
18
0.0
1

CHOOSER
836
328
1000
373
inflammation-dist
inflammation-dist
"uniform" "decreasing"
0

PLOT
1612
604
1893
818
Apoptosis probabilty endothelial cells
NIL
NIL
0.0
30.0
0.0
0.01
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [apop-prob] of endothelials"

INPUTBOX
1029
181
1079
241
layers
3.0
1
0
Number

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

integrated-cardio
true
1
Polygon -2674135 true true 75 90 225 90 240 120 240 150 225 165 240 180 240 195 225 210 75 210 60 195 60 180 75 165 60 150 60 120 75 90
Circle -5825686 true false 135 135 30
Polygon -5825686 false false 60 150 60 120 75 90 225 90 240 120 240 150 225 165 240 180 240 195 225 210 75 210 60 195 60 180 75 165

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

mid-integrated-cardio
false
1
Polygon -2674135 true true 30 135 45 105 75 90 120 90 225 90 255 105 270 135 270 150 270 165 255 195 225 210 75 210 45 195 30 165 30 135
Circle -5825686 true false 129 129 42

msc
false
0
Polygon -7500403 true true 150 30 105 135 15 225 150 195 285 225 195 135 150 30
Polygon -7500403 true true 150 30 105 135 15 225 150 195 285 225 195 135 150 45
Polygon -2064490 true false 150 60 120 135 45 210 150 180 255 210 180 135 150 60

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
