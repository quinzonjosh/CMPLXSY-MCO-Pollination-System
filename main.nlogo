extensions [ palette ]     ; for custom colors

;breed defines custom turtles;mainly useful for when there a different kinds of turtles with their own behavior
breed [ bees bee ]
breed [flowers flower]
breed [seeds seed]

;own defines characteristics belonging to a turtle and or a specific breed.
bees-own [
  nectar-carried
  storingNectar
  hasPollen
]

flowers-own [
  nectar
  nectar-replenish-timer
  isFertilized
  isBloomed
  bloom-timer
  fertilization-timer
  life-span
]

seeds-own [
  growthTime
]

;sets up initial environment including clearing all elements, creating central beehive, spawning bee agents, spawning flower agents,and resetting tick timer.
to setup
  clear-all
  create-beehive
  spawn-bees
  spawn-flowers
  reset-ticks
end

to go
  if stopAt500 [if ticks >= 500 [stop] ]

  bee-move
  bee-lands-on-flower
  randomSeedDeath
  replenish-nectar
  grow-seed
  bloom-flower
  check-and-hatch-seeds
  update-flower-lifespan
  tick

  ;if using yearly cycle then replace tick values with 182 and 364
  if ticks mod rainyStartOnTick = 0 and seasonCycle [ ;switches to rain
    set beeSpeed rainyBeeSpeed
    set chancePollenToDisappear rainyPollenDisappearChance
    set flowerMaxLifeSpan rainyFlowerMaxLifeSpan
    set seedGrowthDuration rainySeedGrowthDuration
    set bloomDuration rainyBloomDuration
  ] if ticks mod dryStartOnTick = 0 and seasonCycle [ ;switches to dry
    set beeSpeed dryBeeSpeed
    set chancePollenToDisappear dryPollenDisappearChance
    set flowerMaxLifeSpan dryFlowerMaxLifeSpan
    set seedGrowthDuration drySeedGrowthDuration
    set bloomDuration dryBloomDuration
  ]
end

to update-flower-lifespan
  ask flowers [
    if bloom-timer >= bloomDuration and not isBloomed [
      set isBloomed true
      set shape "flower"
    ]
    if life-span > 0 [
      set life-span life-span - 1
      if life-span <= 0 [
        die
      ]
    ]
  ]
end

to spawn-bees
  set-default-shape bees "bee"

  create-bees beesInitPopulation [
    set color gray     ; gray if no pollen collected, else green
    set size 1
    setxy (random 5) - 2 (random 5) - 2
    set nectar-carried 0
    set storingNectar false
    set hasPollen false
  ]
end

to create-beehive
  ask patches [
    set pcolor 52 ; dark green
    if abs(pxcor) <= 2 and abs(pycor) <= 2 [
      ifelse abs(pycor) mod 2 = 0 [ set pcolor [221 148 29]] [ set pcolor yellow]
    ]
    if abs(pxcor) = 3 and abs(pycor) <= 1 [
      ifelse abs(pycor) mod 2 = 0 [ set pcolor [221 148 29]] [ set pcolor yellow ]
    ]
    if abs(pxcor) <= 1 and abs(pycor) = 3 [ set pcolor yellow ]
    if abs(pxcor) = 0 and abs(pycor) = 4 [ set pcolor yellow ]
  ]
end

to spawn-flowers
  set-default-shape flowers "flower"
  let totalPatches count patches with [pcolor = 52]
  let availableColors (remove [52] base-colors)

  create-flowers (flowerDensity / 100) * totalPatches [
    move-to one-of patches with [not any? turtles-here and pcolor = 52]
    set isBloomed true
    set nectar maxNectar
    set isFertilized false
    set color one-of availableColors
    set life-span random ( flowerMaxLifeSpan - flowerMinLifeSpan + 1) + flowerMinLifeSpan
  ]
end

to bee-move
  ask bees [
    ; Check if there are flowers with nectar nearby
    let target one-of (flowers with [nectar > 0 and isBloomed] in-radius 5)
    ifelse storingNectar [
      ; If the bee is storing nectar, move back to the beehive
      face patch 0 0
      fd beeSpeed
      if distance patch 0 0 < 2
      [
        bee-store-nectar
      ]
    ]
    [
      ifelse target != nobody [
        face target
        fd beeSpeed
      ]
      [
        ; If no nearby flowers have nectar, move randomly
        rt random 50
        lt random 50
        fd beeSpeed
      ]

      if random-float 1 < 0.1 and hasPollen [ ; 10% chance and currently has pollen
        set hasPollen false
        set label ""  ; Clear label if pollen is lost
      ]
    ]
  ]
end

to bee-store-nectar
  set nectar-carried nectar-carried - 1
  if nectar-carried = 0 [
    set storingNectar false
    set color gray
  ]
end

;All interactions between bee and flower
to bee-lands-on-flower
  ask bees-on flowers [
    let flower-here one-of flowers-here
    if [nectar] of flower-here > 0 and [isBloomed] of flower-here and nectar-carried < beeNectarCapacity [
      ask flower-here [
        set nectar nectar - 1
        if [hasPollen] of myself and random-float 100 < flowerFertilizationRate [ ; Check if the bee has pollen
          set isFertilized true
          set fertilization-timer 0
        ]
      ]
      set nectar-carried nectar-carried + 1
      if nectar-carried >= beeNectarCapacity [ ; If the bee has reached its nectar capacity
        set storingNectar true
      ]
      givePollen
    ]
  ]
end

to check-and-hatch-seeds
  let displacement random 10

  ask flowers with [isFertilized and fertilization-timer >= 10] [

    ; Find valid patches within displacement radius for spawning seeds
    let valid-patches patches in-radius displacement with [pcolor = 52 and not any? flowers-here]

    if count valid-patches > 0 [
      let target-patch one-of valid-patches
      ; call the function hatch-seeds-from, passingthe info of the parent flower and the targeted patch
      hatch-seeds-from self target-patch
    ]
    set isFertilized false ; Reset fertilization status
  ]

  ask flowers with [isFertilized] [
    set fertilization-timer fertilization-timer + 1 ; Increment the timer for fertilized flowers
  ]
end

to hatch-seeds-from [parent-flower target-patch]
  ask parent-flower [
    hatch-seeds 5 [  ; Hatch 5 seeds
      set breed seeds
      set heading random 360
      setxy [pxcor] of target-patch [pycor] of target-patch
      set color brown
      set shape "dot"
      set label ""
      set size 1
      set growthTime 0
    ]
  ]
end

to randomSeedDeath
  ask seeds[
    if random-float 100 < seedDeathChance [
      die
    ]
  ]
end

to givePollen
  ask bees-on flowers[
   set hasPollen true
   set label "POLLEN"
   set color violet
  ]
end

;grants nectar to flower
to replenish-nectar
  ask flowers [
    if nectar < maxNectar [
      ifelse nectar-replenish-timer >= nectarReplenishRate and isBloomed [
        set nectar nectar + 1
        set nectar-replenish-timer 0
      ]
      [
        set nectar-replenish-timer nectar-replenish-timer + 1
      ]
    ]
  ]
end

to grow-seed
  let availableColors (remove [52] base-colors)

  ask seeds [
    ifelse growthTime < seedGrowthDuration [
      set growthTime growthTime + 1
    ]
    [

      set breed flowers
      set color one-of availableColors
      set isBloomed false
      set isFertilized false
      set nectar 0
      set nectar-replenish-timer 0
      set shape "plant"
      set life-span random ( flowerMaxLifeSpan - flowerMinLifeSpan + 1) + flowerMinLifeSpan
    ]
  ]
end

to bloom-flower
  ask flowers with [not isBloomed] [
    ifelse bloom-timer < bloomDuration [
      set bloom-timer bloom-timer + 1
    ]
    [
      set isBloomed true
      set nectar-replenish-timer 0
      set shape "flower"
    ]
  ]
end

;applies season effects
to applyOneSeason
  if currentSeason = "No Season Mode" [ ;default values
    set beeSpeed 1
    set chancePollenToDisappear 0.10
    set flowerMaxLifeSpan 50;
    set seedGrowthDuration 9
    set bloomDuration 4
  ] if currentSeason = "Dry" [ ;bees speed up, flower lifespan decreases due to accelerated wilting.
    set beeSpeed dryBeeSpeed
    set chancePollenToDisappear dryPollenDisappearChance
    set flowerMaxLifeSpan dryFlowerMaxLifeSpan
    set seedGrowthDuration drySeedGrowthDuration
    set bloomDuration dryBloomDuration
  ] if currentSeason = "Rainy" [ ;bees slow down due to colder temperatue, pollen is more likely to be lost due to rain.
    set beeSpeed rainyBeeSpeed
    set chancePollenToDisappear rainyPollenDisappearChance
    set flowerMaxLifeSpan rainyFlowerMaxLifeSpan
    set seedGrowthDuration rainySeedGrowthDuration
    set bloomDuration rainyBloomDuration
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
284
10
699
426
-1
-1
12.33333333333334
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
182
10
245
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
993
382
1165
415
beesInitPopulation
beesInitPopulation
0
100
20.0
1
1
NIL
HORIZONTAL

BUTTON
21
10
95
43
NIL
go
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
43
67
215
100
flowerDensity
flowerDensity
0
100
25.0
1
1
%
HORIZONTAL

TEXTBOX
54
49
204
67
             Flower Settings
10
0.0
1

SLIDER
41
106
213
139
maxNectar
maxNectar
1
10
10.0
1
1
NIL
HORIZONTAL

SLIDER
35
143
212
176
nectarReplenishRate
nectarReplenishRate
0
10
10.0
1
1
ticks
HORIZONTAL

SLIDER
996
419
1168
452
beeNectarCapacity
beeNectarCapacity
1
10
10.0
1
1
NIL
HORIZONTAL

BUTTON
102
10
175
43
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
791
420
986
453
chancePollenToDisappear
chancePollenToDisappear
0
1
0.1
.01
1
NIL
HORIZONTAL

SLIDER
31
183
221
216
flowerFertilizationRate
flowerFertilizationRate
1
100
64.0
1
1
%
HORIZONTAL

SLIDER
38
259
210
292
seedDeathChance
seedDeathChance
0
100
4.0
1
1
%
HORIZONTAL

SLIDER
38
295
210
328
seedGrowthDuration
seedGrowthDuration
1
100
10.0
1
1
ticks
HORIZONTAL

SLIDER
38
220
210
253
bloomDuration
bloomDuration
1
100
10.0
1
1
ticks
HORIZONTAL

SLIDER
37
335
209
368
flowerMinLifeSpan
flowerMinLifeSpan
0
100
25.0
1
1
ticks
HORIZONTAL

SLIDER
35
371
209
404
flowerMaxLifeSpan
flowerMaxLifeSpan
0
100
45.0
1
1
ticks
HORIZONTAL

TEXTBOX
753
10
903
28
           Season Settings
11
0.0
1

CHOOSER
787
26
1008
71
currentSeason
currentSeason
"No Season Mode" "Dry" "Rainy"
1

BUTTON
834
73
959
106
NIL
applyOneSeason
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
886
362
1036
380
              Bee Settings
11
0.0
1

SLIDER
813
381
985
414
beeSpeed
beeSpeed
0.1
3
1.2
0.1
1
NIL
HORIZONTAL

SWITCH
1015
25
1140
58
seasonCycle
seasonCycle
0
1
-1000

SLIDER
806
109
978
142
rainyStartOnTick
rainyStartOnTick
1
364
182.0
1
1
NIL
HORIZONTAL

SLIDER
983
109
1155
142
dryStartOnTick
dryStartOnTick
1
364
364.0
1
1
NIL
HORIZONTAL

SLIDER
983
145
1155
178
dryBeeSpeed
dryBeeSpeed
0
3
1.2
0.1
1
NIL
HORIZONTAL

SLIDER
798
145
977
178
rainyBeeSpeed
rainyBeeSpeed
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
860
182
1119
215
rainyPollenDisappearChance
rainyPollenDisappearChance
0
0.5
0.2
0.01
1
NIL
HORIZONTAL

SLIDER
866
217
1112
250
dryPollenDisappearChance
dryPollenDisappearChance
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
796
253
982
286
rainyFlowerMaxLifespan
rainyFlowerMaxLifespan
0
100
75.0
1
1
NIL
HORIZONTAL

SLIDER
985
252
1160
285
dryFlowerMaxLifespan
dryFlowerMaxLifespan
0
100
45.0
1
1
NIL
HORIZONTAL

SLIDER
787
290
983
323
rainySeedGrowthDuration
rainySeedGrowthDuration
0
100
5.0
1
1
NIL
HORIZONTAL

SLIDER
985
288
1171
321
drySeedGrowthDuration
drySeedGrowthDuration
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
812
326
984
359
rainyBloomDuration
rainyBloomDuration
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
986
326
1158
359
dryBloomDuration
dryBloomDuration
0
100
10.0
1
1
NIL
HORIZONTAL

PLOT
31
430
335
580
populations
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"flowers" 1.0 0 -14439633 true "" "plot count flowers"
"seeds" 1.0 0 -4079321 true "" "plot count seeds"
"growing" 1.0 0 -15575016 true "" "plot count flowers with [shape = \"plant\"]"

SWITCH
1182
21
1288
54
stopAt500
stopAt500
0
1
-1000

MONITOR
355
437
412
482
flowers
count flowers
0
1
11

MONITOR
422
439
479
484
seeds
count seeds
0
1
11

MONITOR
493
439
551
484
growing
count flowers with [shape = \"plant\"]
0
1
11

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

bee
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

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
NetLogo 6.4.0
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
