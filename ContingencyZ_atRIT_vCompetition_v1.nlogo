extensions   ;; import external libraries
[ 
  gis 
]

__includes   ;; specify other NetLogo source files
[
  ;;  NOTE: you may only modify code in "humans.nls" for this competition
  "humans.nls"
]

;; Specify the agent types used in the model - remember that "turtle" refers to all agents, irrespective of breed
breed [humans human]
breed [zombies zombie]
breed [rooms room]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;   VARIABLES (you declare names, not variable types)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals   ;; specifies any global variables, not including those used on the GUI
[
  patches-dataset     ;; global var used when reading map data, required by GIS extension
]

zombies-own   ;; variables specific only to agents of the zombie breed
[
  z.speed
  z.isInChase  
]

patches-own   ;; specifies any patch-specific attributes that each patch may individually set
[
  patch-type
  room-number
]

rooms-own
[
  r.room-number
  r.countZombies   ;; number of Zombies at door
  r.countHumans    ;; number of Humans inside room
  r.isSafe?
  r.door           ;; list of patches at door
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;   SETUP METHODS / INITIALIZE WORLD
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  
  ;; The juding panel will set the random seed for repeatable results here
  ;; If not set, each run will result in different outcomes
  ;; random-seed 136    
  random-seed seed
  
  setup-world
  
  ask patches
  [
    ;; Update user defined attributes    
    p.initialize
  ]  
  
  ;; Instantiate agents based on the random seed  
  identifyRooms
  setupSafeRooms
  createZombies
  createLMIers  
  
end

;; Load in the LMI floorplan and convert to an NetLogo world
to setup-world
  ;; these enable use of the GIS extension library here
  ;;import-drawing "Competition LOGO.png"
  
  set-patch-size 2.5
  resize-world -160 160 -138 138  ;; NetLogo coordinate origin is in the center so world dimensions are half of each length
    
  set patches-dataset gis:load-dataset "RIT_Floorplan.asc"
  gis:set-world-envelope gis:envelope-of patches-dataset
  match-cells-to-patches
  gis:apply-raster patches-dataset patch-type
  
  ask patches
  [
    if(patch-type = 0) [set pcolor black]
    if(patch-type = 255) [set pcolor white]
    if(patch-type = 84) [set pcolor cyan]
    if(patch-type = 139) [set pcolor black]  ;; building maintenance areas or otherwise unaccessible
  ]
end

to match-cells-to-patches
  gis:set-world-envelope gis:raster-world-envelope patches-dataset 0 0
  clear-turtles
end

;; Instantiate human population based on the GUI setting
to createLMIers
  ;; instantiate humans randomly in the hallways, but cannot instantiate in a saferoom
  ask n-of numHumans patches with [pcolor != black and not any? other turtles-here and room-number = 0]
  [
    sprout-humans 1
    [
      set color 25
      set shape "person"
      set size 3.5
      set h.isInChase false      
      h.initialize
    ]
  ]
end

;; Identify rooms
to identifyRooms
  ask patches with [patch-type = 84]  ;; note that 84 is equivalent to the color "cyan"
  [
    set room-number 0    ;; to initially identify all saferooms
  ]
  let rn 0  
  loop
  [
    ifelse any? patches with [room-number = 0 and patch-type = 84]  ;; if any rooms still require processing
    [
      set rn rn + 1   ;; start with room number 1 and increment from there
      ask one-of patches with [room-number = 0 and patch-type = 84]   ;; start in a random room
      [
        updateRoomNumber rn  ;; calls a procedure that updates all patches in the room, assigning a room number
        sprout-rooms 1
        [
          set r.room-number rn
          set r.countZombies 0
          set r.countHumans 0
          set shape "flag"   ;; room identifier object
          set color white
          set size 4
          set r.isSafe? true   ;; temporarily set all rooms as a saferoom upon instantiation (to be updated later)
          let _pxcor mean [pxcor] of patches with [room-number = rn]
          let _pycor mean [pycor] of patches with [room-number = rn]          
          setxy _pxcor _pycor   ;; places the flag in the middle of the room
          
          ;; define the doorway and patches around it
          let _list []
          ask patches with [ room-number = rn ]
          [
            if any? (neighbors with [pcolor = white])  ;; any room patches next to white patches can be deduced to be in a doorway
            [
              set _list lput self _list                ;; adds any patches inside the room, and in the doorway to a list
              ask neighbors with [pcolor = white]
              [
                set _list lput self _list              ;; adds any patches outside the room, and in the doorway to a list
              ]
            ]
          ]
          set r.door remove-duplicates _list           ;; adds both temporary lists above into the room-owned list of doorway patches  
          ;; hide-turtle
        ]
      ]
    ]
    [
      stop   ;; else condition --- no unassigned saferooms exist and we can exit loop
    ]
  ]
end    
  
to updateRoomNumber [n]
  ask neighbors with [patch-type = 84 and room-number = 0]
  [
    set room-number n      ;; override default of 0
    updateRoomNumber n     ;; implements a recursive loop within the procedure (note it calls itself)
  ]
end

;; Setup safe rooms bases on number on slider  
to setupSafeRooms
  let _rn number-of-safe-rooms    ;; specifies the number of saferooms assigned from the slider bar on the GUI
  loop
  [
    set _rn _rn + 1
    
    if not any? patches with [room-number = _rn] [ stop ]     ;; stop condition that allows process to exit the loop
    
    ask patches with [room-number = _rn]    ;; sets a room to become "not safe" anymore and goes back to white
    [
      set pcolor white
      ask one-of rooms with [r.room-number = _rn]      
      [
        set r.isSafe? false
      ]      
    ]
  ]   
  
end




;; Instantiate zombie population based on the GUI setting
to createZombies
  ;; create all zombies near the main stairwell
  ;;ask n-of numZombies patches with [pcolor = white and not any? other turtles-here and pxcor >= -117 and pxcor <= -114 and pycor >= 40 and pycor <= 46 ]
  ask n-of numZombies patches with [pcolor = white and not any? other turtles-here]
  [
    sprout-zombies 1
    [   
      set color green
      set shape "person"
      set size 3.5
      
      set label-color 63
      ;; In a zombie voice, say "Grrrrr....."
      set label "Grrrr..."
    
      set z.isInChase false
      
    ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;   MAIN
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  
  ;; update room statistics
  ask rooms with [r.isSafe? = true]
  [
    let _room-number r.room-number
    let _countHumans 0
    let _countZombies 0
    ask patches with [room-number = _room-number]
    [
      set _countHumans _countHumans + count humans-here    ;; sums up all humans in a saferoom
    ]
    
    foreach r.door     ;; patches in doorway, both inside and outside the saferoom
    [
      ask ?
      [
        set _countZombies _countZombies + count zombies-here    ;; sums up all zombies in the doorway
      ]
    ]        
       
    set r.countHumans _countHumans
    set r.countZombies _countZombies    
  ]
  
  ask rooms with [r.isSafe? = true and r.countZombies > r.countHumans and r.countHumans > 0 and r.countHumans < 5]  ;; Note: 5+ humans will ALWAYS prevail
  [
    ;; zombies overpower humans inside the saferoom and break in!!!!  Poor humans...
    let _room-number r.room-number
    set r.isSafe? false   ;; "door breaks" permanently and the room is no longer a saferoom for the duration of the model run
    ask patches with [room-number = _room-number]
    [
      set pcolor white    ;; change color from cyan to white
    ]
  ]   
  
  ;; Check for zombies and adjust heading and speed accordingly
  ;;h.scanForZombies    
  
  ;; Based on speed and heading (which you can update from humans.nls), move if possible
  ask humans
  [
    ;; Move the human
    let _xcor xcor
    let _ycor ycor
    
    ;; see if zombies nearby
    h.scanForZombies  
    
    setxy _xcor _ycor
    move-humans
  ]
  
  ask zombies 
  [
    ;; See if any humans nearby
    z.smellForHumans
    
    ;; Move towards closest human if any
    move-zombies
    
    ;; Engage human
    z.engageHuman 
  ]    
  
  ;; End the simulation if the time limit of 1000 tick is reached, or no humans have survived
  if (ticks >= 1000) or (count humans = 0) [ stop ]

  ;; Advance the tick counter by one
  tick
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;   ZOMBIE METHODS
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to z.smellForHumans
  ;; Set default speed
  ;; Changed if found human or zombie following a human
  set z.speed 1.0
  set z.isInChase false  
  if any? humans  
  [    
    let _zombie self
    let _human min-one-of humans [measure-distance _zombie self]         
    ifelse measure-distance _zombie _human < zombieSmellRadius
    [
      ;; Found human <= zommbieSmellRadius without a wall between the human and zombie
      face _human        
      set z.speed 1.4
      set z.isInChase true
    ] 
    [
      ;; find closet zombie that isInChase if any
      if count zombies with [z.isInChase = true] > 0
      [
        let _zombieInChase min-one-of zombies with [z.isInChase = true][measure-distance _zombie self]
        if measure-distance _zombie _zombieInChase < 1000
        [
          face _zombieInChase
          set z.speed 1.4         ;; faster speed because zombie found zombie followiing a human
          set z.isInChase false   ;; false because not following human directly
        ]
      ]
    ]      
  ]
end

to z.engageHuman 
  ;; If there are any humans within reach of the zombie...
  if any? humans-on (patch-set neighbors patch-here)
  [
    ;; Human is in range of the zombie! (includes neighbors and current patch)
    let h one-of humans-on (patch-set neighbors patch-here)
    
    ;; Runs this procedure from the humans.nls file to broadcast that a zombie was encountered
    h.zombieEncountered h
    
    ;; Zombie engages the human and a battle begins!
    show (word "Grraaaahhhh, hungggrryyy...")
    let draw random-float 1.0
    show (word "zombie attack rolls a " draw)
    ifelse draw < zombieProbabilityKillHuman
    [
      ;; Zombie wins the fight
      show (word "Grrrr... yummy...")
      
      ;; Ask human in the engagement to die and create a zombie in its place
      ask h [die]
      hatch-zombies 1
      [
        set color green
        set shape "person"
        set size 4
    
        set label-color 63
        set z.isInChase false
        set label "Grrrr..."
      ]
    ]
    [
      ;; Human wins the fight
      show (word "The Bobble-Z will be mine!")
      
      ;; Runs this procedure from the humans.nls file to broadcast that a zombie was killed
      h.killedZombie h
      
      ;; ask the zombie in this engagement to die
      die
    ]
  ]
end

;; Move procedure for humans - NOTE: this only makes humans move forward and prevents moving through walls
;; If a wall is encountered humans will change direction to a random nearby non-wall patch
;; In the humans.nls file, you are challenged with changing the human heading/facing direction, and speed
;; Given the changes you've made, this movement logic here will use what heading and speed you establish in humans.nls
to move-humans   
  ifelse ([pcolor] of patch-ahead h.speed = black) or ( [pcolor] of patch-ahead 1 = black )  ;; OR-condition necessary since speed can make a human jump through walls
  [
    ;; A wall has been encountered in the path, so move to a nearby non-wall patch
    let _new-patch (one-of neighbors with [pcolor != black] )   ;; can include cyan
    face _new-patch
    move-to _new-patch
  ]
  [
    ;; No wall in the way, so move forward
    fd h.speed
  ]
end

;; Zombies can only move through white patches. It cannot be black (wall) or cyan (safe zone)
to move-zombies
  ifelse ([pcolor] of patch-ahead z.speed = white) and ( [pcolor] of patch-ahead 1 = white )
  [
    ;; No obstruction or safe zone, so move is valid
    fd z.speed
  ]
  [
    ;; Wall or safe zone patch encountered in path, so reroute to nearby valid patch and move
    let _new-patch (one-of neighbors with [pcolor = white] )
    face _new-patch
    move-to _new-patch
  ]
end

;; Reports distance between two turtles (two zombies, two humans or zombie and human)
;; Reports 1000 if there is a wall between the two turtles;; 
to-report measure-distance [z h]
  let _distance 1000
  ask z
  [    
    ;; Save current heading
    let _heading [heading] of z

    ;; Save current position
    let _xcor xcor
    let _ycor ycor

    face h
    let _wall-found? false
    while [distance h > 1 and not _wall-found?]
    [
      if [pcolor] of patch-here = black [set _wall-found? true]
      fd 1
    ]    

    ;; Reset orginal position and heading of zombie
    set heading _heading
    setxy _xcor _ycor     
    
    ifelse _wall-found? [ set _distance 1000 ][ set _distance distance h ] 
  ]
  
  report _distance

end
    
    
  
      

      
    
    
  
  
@#$#@#$#@
GRAPHICS-WINDOW
207
10
1019
733
160
138
2.5
1
10
1
1
1
0
0
0
1
-160
160
-138
138
1
1
1
ticks
30.0

BUTTON
4
10
67
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

BUTTON
70
10
133
43
step
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

BUTTON
137
10
200
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
5
130
185
163
numHumans
numHumans
1
100
50
1
1
NIL
HORIZONTAL

SLIDER
5
235
185
268
numZombies
numZombies
0
25
20
1
1
NIL
HORIZONTAL

SLIDER
4
275
184
308
zombieSmellRadius
zombieSmellRadius
0
200
25
1
1
NIL
HORIZONTAL

SLIDER
5
169
185
202
zombieAwarenessRadius
zombieAwarenessRadius
1
100
41
1
1
NIL
HORIZONTAL

SLIDER
3
315
184
348
zombieProbabilityKillHuman
zombieProbabilityKillHuman
0
1
0.75
0.01
1
NIL
HORIZONTAL

TEXTBOX
7
110
157
128
HUMAN PARAMETERS
11
0.0
1

TEXTBOX
7
215
157
233
ZOMBIE PARAMETERS
11
0.0
1

PLOT
2
362
202
512
Agent Populations
Time
Population Count
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Humans" 1.0 0 -955883 true "" "plot count humans"
"Zombies" 1.0 0 -11085214 true "" "plot count zombies"

MONITOR
4
524
202
569
Human Population
count humans
0
1
11

MONITOR
5
576
202
621
Zombie Population
count zombies
0
1
11

SLIDER
6
70
180
103
number-of-safe-rooms
number-of-safe-rooms
0
35
20
1
1
NIL
HORIZONTAL

TEXTBOX
9
54
159
72
ENVIRONMENT
11
0.0
1

INPUTBOX
4
626
202
686
seed
67890
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
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count humans</metric>
    <metric>count zombies</metric>
    <enumeratedValueSet variable="numZombies">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="zombieAwarenessRadius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numHumans">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="zombieProbabilityKillHuman">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="zombieSmellRadius">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count humans</metric>
    <enumeratedValueSet variable="numZombies">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="zombieAwarenessRadius">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numHumans">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-number">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="80"/>
      <value value="90"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="zombieProbabilityKillHuman">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="zombieSmellRadius">
      <value value="200"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="contest" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count humans</metric>
    <metric>count zombies</metric>
    <enumeratedValueSet variable="seed">
      <value value="1234"/>
      <value value="12345"/>
      <value value="23456"/>
      <value value="34567"/>
      <value value="45678"/>
      <value value="56789"/>
      <value value="67890"/>
      <value value="78901"/>
      <value value="89012"/>
      <value value="90123"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count humans</metric>
    <metric>count zombies</metric>
    <enumeratedValueSet variable="seed">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
