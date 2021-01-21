extensions [csv]

;;;;;;;;;;;;;;;;;;;;;;;; GLOBALS ;;;;;;;;;;;;;;;;;;;;;;;;
globals [
  proposed-projects
  current-month
  current-year
  ; Political-Scenario variables
  change-in-openness
  change-in-variety

  offshore-small-groups
  offshore-medium-groups
  offshore-large-groups
  onshore-small-groups
  onshore-medium-groups
  onshore-large-groups

  receiving-municipalities
  responsible-municipality

  n-projects

]




;;;;;;;;;;;;;;;;;;;;;;;; BREEDS & BREED VARIABLES ;;;;;;;;;;;;;;;;;;;;;;;;
breed [municipalities municipality]
breed [projects project]

municipalities-own [
  name
  inhabitants
  yearly-budget
  allocated-funds
  available-personnel
  green-energy-openness
  political-variety
  city-council-size
]

projects-own [
  active
  cost
  installed-power
  project-type
  project-size
]


;;;;;;;;;;;;;;;;;;;;;;;; LINKS & LINK VARIABLES ;;;;;;;;;;;;;;;;;;;;;;;;
undirected-link-breed [municipality-connections municipality-connection]
directed-link-breed [project-connections project-connection]


municipality-connections-own [trust] ; trust ranges from 0 to 100, the values from the csv range in 5 discrete steps (0 to 5) which are then scaled up

project-connections-own [
  personnel
  knowledge-needed
  priority ; integer, the higher the priority, the more is invested in a project
  owner ; boolean, whether the municipality is the owner of a project
  positively-affected ; boolean, whether a municipality is positively affected
  negatively-affected ; boolean, whether a municipality is negatively affected

]

;;;;;;;;;;;;;;;;;;;;;;;;  SETUP FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks

  set current-month 1
  set current-year 2021

  setup-municipalities
  setup-informal-network
  setup-projects
  setup-scenarios
  setup-municipality-groups


end


to setup-municipalities

  file-close-all ; close all open files

  if not file-exists? "data/municipalities.csv" [
    error "No 'municipalities.csv' file found!"
  ]
  let fileHeader 1 ; there is 1 header line, line 1 is the first data line (dont forget, we cunt from 0)

  file-open "data/municipalities.csv"

  ; need to skip the first fileHeader rows
  let row 0 ; the row that is currently read

  ; We'll read all the data in a single loop
  while [ not file-at-end? ] [
    ; here the CSV extension grabs a single line and puts the read data in a list
    let data (csv:from-row  file-read-line)

    ; check if the row is empty or not
    if fileHeader <= row  [ ; we are past the header

      ;create turtles
      create-municipalities 1 [
        ; Variables
        set name item 0 data
        set inhabitants item 1 data
        set yearly-budget item 2 data
        set available-personnel item 3 data
        set green-energy-openness item 4 data
        set political-variety item 5 data
        set allocated-funds 0
        set label name
        set color blue
        set shape "circle"

        ; Determine number of city council seats (source: https://nl.wikipedia.org/wiki/Gemeenteraad#Nederland)
        if inhabitants > 0 [set city-council-size 9]
        if inhabitants > 3000 [set city-council-size 11]
        if inhabitants > 6000 [set city-council-size 13]
        if inhabitants > 10000 [set city-council-size 15]
        if inhabitants > 15000 [set city-council-size 17]
        if inhabitants > 20000 [set city-council-size 19]
        if inhabitants > 25000 [set city-council-size 21]
        if inhabitants > 30000 [set city-council-size 23]
        if inhabitants > 35000 [set city-council-size 25]
        if inhabitants > 40000 [set city-council-size 27]
        if inhabitants > 45000 [set city-council-size 29]
        if inhabitants > 50000 [set city-council-size 31]
        if inhabitants > 60000 [set city-council-size 33]
        if inhabitants > 70000 [set city-council-size 35]
        if inhabitants > 80000 [set city-council-size 37]
        if inhabitants > 100000 [set city-council-size 39]
        if inhabitants > 200000 [set city-council-size 45]

        ;preliminary personnel setting based on inhabitants
        set available-personnel round (inhabitants / 50000 * 2)

        ; municipalities are generated in the upper part of the screen
        let x-cor random-xcor
        let y-cor random-ycor
        ;while [x-cor <= world-width / 2] [set x-cor random-xcor]
        ;while [y-cor <= world-height / 2] [set y-cor random-ycor]
        setxy x-cor y-cor


        set size (0.3 * log inhabitants 10)
      ]
    ];end past header

    set row row + 1 ; increment the row counter for the header skip

  ]; end of while there are rows

  file-close ; make sure to close the file

end


to setup-informal-network
  let trust-ratings csv:from-file "data/trust_ratings.csv" ; read in trust ratings from table

  ask municipalities [
    create-municipality-connections-with other municipalities ; create connections with all other municipalities

    let municipality-id who ; work-around to call the current municipality id later on

    ask my-out-municipality-connections [
      if trust = 0 [ ; in case the trust is zero, possibly override
        let municipality-trust item (municipality-id + 1) trust-ratings ; select the correct row from the trust table
        set trust (item ([who] of other-end + 1) municipality-trust * 20) ; select the correct column from the trust table
      ]
    ]
  ]

  repeat 20 [
    update-layout
  ]


end


to setup-projects

  file-close-all ; close all open files

  if not file-exists? "data/projects.csv" [
    error "No file 'projects.csv' found!"
  ]
  let fileHeader 1 ; there is 1 header line, line 1 is the first data line (dont forget, we count from 0)

  file-open "data/projects.csv"

  ; need to skip the first fileHeader rows
  let row 0 ; the row that is currently read

  ; We'll read all the data in a single loop
  while [ not file-at-end? ] [
    ; here the CSV extension grabs a single line and puts the read data in a list
    let data (csv:from-row  file-read-line)

    ; check if the row is empty or not
    if fileHeader <= row  [ ; we are past the header

      ; a higher amount of small projects can be carried out, while sites available for large plants are geographically limited.
      ; according to the configuration below, it is possible for each costal municipality (five in total) to conceive a small or medium offshore project as worthy of consideration
      ; small wind or solar projects are possible for each municipality which has the geographical space needed within their territory. Similarly for medium projects.
      if (item 0 data = "windpark-small-onshore") or (item 0 data = "solarpark-small") [set n-projects 9]
      if (item 0 data = "windpark-small-offshore") or (item 0 data = "windpark-medium-offshore") or (item 0 data = "windpark-medium-onshore") or (item 0 data = "solarpark-medium") [set n-projects 5]
      if (item 0 data = "windpark-large-offshore") or (item 0 data = "windpark-large-onshore") or (item 0 data = "solarpark-large") [set n-projects 2]

      ;create possible energy projects
      create-projects n-projects [
        ; Variables
        set project-type item 0 data
        set cost item 1 data
        set installed-power item 2 data
        set project-size item 3 data
        set shape project-type

        let x-cor random-xcor
        let y-cor random-ycor

        set size 3
        set hidden? True
      ]

    ];end past header

    set row row + 1 ; increment the row counter for the header skip

  ]; end of while there are rows

  file-close ; make sure to close the file

end

to setup-municipality-groups
  ;initialize the municipality groups. They will later be populated by all the possible
  ; angentsets of municipalities that, together, can be assigned to a single energy project
      set offshore-small-groups []
      set offshore-medium-groups []
      set offshore-large-groups []
      set onshore-small-groups []
      set onshore-medium-groups []
      set onshore-large-groups []



  file-close-all ; close all open files

  if not file-exists? "data/municipality_groups.csv" [
    error "No file 'projects.csv' found!"
  ]
  let fileHeader 1 ; there is 1 header line, line 1 is the first data line (dont forget, we count from 0)

  file-open "data/municipality_groups.csv"

  ; need to skip the first fileHeader rows
  let row 0 ; the row that is currently read

  ; We'll read all the data in a single loop
  while [ not file-at-end? ] [
    ; here the CSV extension grabs a single line and puts the read data in a list
    let data (csv:from-row  file-read-line)

    ; check if the row is empty or not
    if fileHeader <= row  [ ; we are past the header

      repeat 1 [
        ; setup the global variables realted to municipality groups
        if item 0 data = "offshore-small" [
          ; read and store the row of the csv file, this represents a list/group of municipalities which can be
          ; assigned a small offshore windpark project
          let offshore-small-group municipalities with [(name = item 1 data) OR (name = item 2 data) OR (name = item 3 data)]

          ; add such row to the list of all possible groups/lists of municipalities that can be assigned
          ; a small offshore windpark project
          set offshore-small-groups lput offshore-small-group offshore-small-groups
        ]

        if item 0 data = "offshore-medium" [
          ; read and store the row of the csv file, this represents a list/group of municipalities which can be
          ; assigned a medium offshore windpark project
          let offshore-medium-group municipalities with [(name = item 1 data) OR (name = item 2 data) OR (name = item 3 data) OR (name = item 4 data)]

          ; add such row to the list of all possible groups/lists of municipalities that can be assigned
          ; a medium offshore windpark project
          set offshore-medium-groups lput offshore-medium-group offshore-medium-groups
        ]

        if item 0 data = "offshore-large" [
          ; since the list of all possible groups/lists of municipalities that can be assigned a large offshore windpark project
          ; is composed only of one agentset
          set offshore-large-groups municipalities with [(name = item 1 data) OR (name = item 2 data) OR (name = item 3 data) OR (name = item 4 data) OR (name = item 5 data)]
        ]

        if item 0 data = "onshore-small" [
          ifelse item 3 data != ""
          [let onshore-small-group municipalities with [(name = item 1 data) OR (name = item 2 data) OR (name = item 3 data)]
           set onshore-small-groups lput onshore-small-group onshore-small-groups]
          [ifelse item 2 data != ""
            [let onshore-small-group municipalities with [(name = item 1 data) OR (name = item 2 data)]
             set onshore-small-groups lput onshore-small-group onshore-small-groups]
            [let onshore-small-group municipalities with [name = item 1 data]
             set onshore-small-groups lput onshore-small-group onshore-small-groups]
          ]
        ]

        if item 0 data = "onshore-medium" [
          ifelse item 3 data != ""
          [let onshore-medium-group municipalities with [(name = item 1 data) OR (name = item 2 data) OR (name = item 3 data)]
           set onshore-medium-groups lput onshore-medium-group onshore-medium-groups]
          [ifelse item 2 data != ""
            [let onshore-medium-group municipalities with [(name = item 1 data) OR (name = item 2 data)]
             set onshore-medium-groups lput onshore-medium-group onshore-medium-groups]
            [let onshore-medium-group municipalities with [name = item 1 data]
             set onshore-medium-groups lput onshore-medium-group onshore-medium-groups]
          ]
        ]

       if item 0 data = "onshore-large" [
          ifelse item 3 data != ""
          [let onshore-large-group municipalities with [(name = item 1 data) OR (name = item 2 data) OR (name = item 3 data)]
           set onshore-large-groups lput onshore-large-group onshore-large-groups]
          [ifelse item 2 data != ""
            [let onshore-large-group municipalities with [(name = item 1 data) OR (name = item 2 data)]
             set onshore-large-groups lput onshore-large-group onshore-large-groups]
            [let onshore-large-group municipalities with [name = item 1 data]
             set onshore-large-groups lput onshore-large-group onshore-large-groups]
          ]
        ]
      ]

    ];end past header

    set row row + 1 ; increment the row counter for the header skip

  ]; end of while there are rows

  file-close ; make sure to close the file

end


to setup-scenarios
  if Political-Scenario = "Green awareness"[
    set change-in-openness 5
    set change-in-variety  0
  ]

  if Political-Scenario = "Conservative push"[
    set change-in-openness -5
    set change-in-variety  0
  ]

  if Political-Scenario = "Polarization"[
    set change-in-openness 0
    set change-in-variety 5
  ]

  if Political-Scenario = "Consolidation"[
    set change-in-openness 0
    set change-in-variety -5
  ]


end

;;;;;;;;;;;;;;;;;;;;;;;; GO FUNCTION ;;;;;;;;;;;;;;;;;;;;;;;;

to go

  ; stop simulation if year 2051 is reached
  if (current-year > 2050)[ stop ]

  ; Handle the external factors
  external-factors

  ; Do municipality actions
  ask municipalities [

    manage-projects

    communicate-informally
  ]



  ; Do visuals
  update-layout

  tick


end


;;;;;;;;;;;;;;;;;;;;;;;; OTHER FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;


; Function to deal with the external factors
to external-factors

  ; Do timekeeping
  ; In case the year is not over yet
  ifelse current-month < 12 [
    set current-month current-month + 1
  ]
  ; In case a new year starts
  [
    set current-month 1
    set current-year current-year + 1

    ;Set a new budget
    ask municipalities [
      set yearly-budget (yearly-budget * (1 + yearly-budget-increase / 100))
    ]


  ]


  ; In case an election happens (every four years)
  if ((current-year - 2018) mod 4) = 0 and current-month = 1 [
    ;Change political variety based on external scenarios
    output-print (word "POLITICAL: Year " current-year ": An election took place")

    ask municipalities [
      set green-energy-openness green-energy-openness  + random-float 1 * change-in-openness
      set political-variety  political-variety + random-float 1 * change-in-variety
    ]

  ]


  project-proposals-generation


end



to project-proposals-generation
  ; on average, every year a new project is proposed to and taken into account by a municipality in the region
  ;set proposed-projects n-of (max list 0 random-normal 0.083 0.7) projects ; 0.083 is an approximation of 1/12
  set proposed-projects n-of random ((total-project-proposal-frequency + 1) / 12) projects with [hidden? = True]
  ask proposed-projects [
    ; Duplicate the project so that there are always sufficient projects
    hatch 1 [
      set hidden? True
      setxy random-xcor random-ycor

    ]
    ; once projects are proposed to and taken into account by a municipality, they are shown and associated with the municipality which received it


    ; a group of municipalities will be concerned by the proposed project
    if project-type = "windpark-small-offshore"  [set receiving-municipalities one-of offshore-small-groups]
    if project-type = "solarpark-small"  [set receiving-municipalities one-of onshore-small-groups]
    if project-type = "windpark-small-onshore"  [set receiving-municipalities one-of onshore-small-groups]
    if project-type = "windpark-medium-offshore"   [set receiving-municipalities one-of offshore-medium-groups]
    if project-type = "solarpark-medium"   [set receiving-municipalities one-of onshore-medium-groups]
    if project-type = "windpark-medium-onshore"   [set receiving-municipalities one-of onshore-medium-groups]
    if project-type = "windpark-large-offshore"  [set receiving-municipalities one-of offshore-large-groups]
    if project-type = "solarpark-large"  [set receiving-municipalities one-of onshore-large-groups]
    if project-type = "windpark-large-onshore"  [set receiving-municipalities one-of onshore-large-groups]


    ; determine the knowledge needed depending on the project size
    let knowledge-needed-for-project 0
    if (project-size = 1) [set knowledge-needed-for-project 50] ; in months*person (only managerial knowledge, perhaps the technical one is out of scope, since it would be so much (entire teams of workers
    if (project-size = 2) [set knowledge-needed-for-project 100] ; not belonging to the municipality).
    if (project-size = 3) [set knowledge-needed-for-project 200]

    ; one municipality will actually receive and take into account the project, i.e. the "responsible municipality"
    ; while all others will only be "positively affected" or "negatively affected". Naturally, the responsible municipality will also be
    ; positively or negatively affected by the project.

    ifelse is-agentset? receiving-municipalities[
      set responsible-municipality one-of receiving-municipalities
    ][
      set responsible-municipality receiving-municipalities
    ]

    ; Create link to the project owner
    create-project-connection-to responsible-municipality [  ; remember to use "create-project-connection agent" to create 1 link, while "create-project-connections agentset" to create multiple

      set knowledge-needed knowledge-needed-for-project
      set priority 10 ; initial prio is 10 if a municipality is a project owner
      set personnel 0 ; this should be the number of people a municipality wants to devote to this project, it will increase, decreasing the available personnel of the municipality
      set positively-affected True ; a municipality responsible is assumed to benefit from a project automatically
      set owner True ; set the municipality to the "responsible" municipality
      set shape "project-owner"
    ]

    ; Check if there are multiple municipalities left in the agentset
    if is-agentset? receiving-municipalities [

      ; remove responsible municipality from agent set
      ask responsible-municipality [
        set receiving-municipalities other receiving-municipalities
      ]

      if is-agentset? receiving-municipalities [
        create-project-connections-to receiving-municipalities [
          set owner False
          set shape "project-externality"
          set priority 0 ; initial prio is 0 if a municipality is only affected

          let externality one-of [ true false ] ; true = positive externalities, false = negative externalities
          ifelse externality [
            set positively-affected True
            set negatively-affected False
            set color 83
          ][
            set positively-affected False
            set negatively-affected True
            set color 23
          ]


        ]
      ]
    ]
    ; Show project on map
    set hidden? False



  ]


end


to manage-projects

  ; Check whether there are new projects that do not have any personnel assigned
  let new-projects my-project-connections with [personnel = 0 AND owner = True]

  if any? new-projects [

    ; Get the number of votes needed depending on the aggregation rules
    let number-votes-needed round (0.5 * city-council-size)

    ; Iterate over the new projects proposed
    ask new-projects [

      let project-to-discuss other-end

      ; In 50% of the cases, the city council decision is delayed
      if random-float 1 > 0.5 [
        if show-project-delay [
          output-print (word "PROJECT DELAYED IN CITY COUNCIL: " [project-type] of project-to-discuss " in " [name] of myself)
        ]
        stop
      ]

      ; Threshold to vote yes depends on the size of the project
      let threshold 0
      if [project-size] of project-to-discuss = 1 [set threshold 30]
      if [project-size] of project-to-discuss = 2 [set threshold 40]
      if [project-size] of project-to-discuss = 3 [set threshold 50]

      let number-pro-votes 0

      repeat [city-council-size] of myself [
        if random-normal [green-energy-openness] of myself [political-variety] of myself > threshold [set number-pro-votes number-pro-votes + 1]
      ]

      ; Check for vote results
      ifelse number-pro-votes >= number-votes-needed [
        ; in case a project is accepted, assign one person working on the project
        if show-project-approvals [
          output-print (word "PROJECT ACCEPTED IN CITY COUNCIL: " [project-type] of project-to-discuss " in " [name] of myself " (" number-pro-votes " out of " number-votes-needed " votes needed)")
        ]

        set personnel 0.5 ; to recognize in a later step that the project was accepted

        ; If accepted, the trust towards a municipality with negative externalities is reduced
        let negatively-affected-municipalities turtle-set nobody

        ask [link-neighbors] of project-to-discuss [
          if [negatively-affected = True] of link-with project-to-discuss [
            set negatively-affected-municipalities (turtle-set negatively-affected-municipalities self)
          ]
        ]

        if any? negatively-affected-municipalities [
          print (word "Several municipalities are negatively affected by the project of " [name] of myself ":")
        ]

        let project-manager myself

        ask negatively-affected-municipalities [
          ask municipality-connection-with project-manager [
            print (word "Trust decreased between " [name] of project-manager " (project manager) and " [name] of myself)
            set trust trust * 0.8
          ]

        ]





      ][
        ; in case a project is rejected

        if show-project-rejections [
          output-print (word "PROJECT REJECTED IN CITY COUNCIL: " [project-type] of project-to-discuss " in " [name] of myself " (" number-pro-votes " out of " number-votes-needed " votes needed)")
        ]
        ask project-to-discuss [die]
      ]
    ]
  ]

  ; Assign the available personnal to the projects relative to their size in GwH (larger projects are assigned more people)
  let projects-in-progress my-project-connections with [personnel > 0 AND owner = True]
  if any? projects-in-progress [

    ; Get total GwH of all the projects proposed
    let total-gwh 0
    ask projects-in-progress [
      set total-gwh total-gwh + [installed-power] of other-end
    ]

    ; Assign the personal relative to the project size
    ask projects-in-progress [
      set personnel max list 1 round ([available-personnel] of myself * [installed-power] of other-end /  total-gwh)
    ]


  ]


  ; Gain project-specific knowledge based on personell assigned to the projects
  ask my-project-connections [
     set knowledge-needed max list 0  (knowledge-needed - personnel)
  ]




end


to communicate-informally

  ; Exchange project-specific knowledge, based on
  ; - trust and on the
  ; - similarities from the projects that are about to be implemented


  ; Form coalitions with other actors, based on
  ; - externalities
  ; -





end


;;;;;;;;;;;;;;;;;;;;;;;; DISPLAY FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;
to update-layout
  ; Color based on different trust values
  ask municipality-connections [
    ifelse trust = 0 [ hide-link ] [
      show-link
      set color (50 + trust / 20)
    ]
  ]

  layout-spring municipalities municipality-connections with [trust > 50]  0.5 10 3
  layout-spring municipalities municipality-connections with [trust > 0]  0.5 20 3
  layout-spring municipalities municipality-connections with [trust = 0]  0.5 70 3

  layout-spring turtles project-connections 0.5 15 2


end
@#$#@#$#@
GRAPHICS-WINDOW
10
24
546
561
-1
-1
6.95
1
10
1
1
1
0
0
0
1
0
75
0
75
0
0
1
ticks
30.0

BUTTON
557
24
770
57
Setup model run
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

CHOOSER
558
194
769
239
Political-Scenario
Political-Scenario
"Base Case" "Conservative push" "Green awareness" "Polarization" "Consolidation"
0

OUTPUT
918
25
1402
207
13

MONITOR
921
228
978
273
Year
current-year
17
1
11

MONITOR
921
277
978
322
Month
current-month
17
1
11

PLOT
998
228
1198
378
Political Overview
Green Energy Openness
Count
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"green-energy-openness" 1.0 1 -13840069 true "" "histogram [green-energy-openness] of municipalities"

SLIDER
558
151
769
184
yearly-budget-increase
yearly-budget-increase
-15
15
3.0
1
1
%
HORIZONTAL

BUTTON
558
61
769
94
Start model run
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

PLOT
1204
229
1404
379
Budget Overview
Tick
Budget
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [yearly-budget] of municipalities"

PLOT
756
385
1140
535
Projects overview
Tick
Number Projects
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Accepted by municipalities" 1.0 0 -16777216 true "" "plot count project-connections with [owner = True]"
"Projects implemented" 1.0 0 -14439633 true "" "plot count projects with [active = True]"

CHOOSER
558
246
770
291
Aggregation-Rules
Aggregation-Rules
"Unanimity" "Majority"
0

PLOT
1147
384
1405
534
Knowlege Overview
Tick
Person*Month
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Knowledge needed" 1.0 0 -16777216 true "" "plot sum [knowledge-needed] of project-connections with [owner = True]"

SLIDER
558
111
769
144
total-project-proposal-frequency
total-project-proposal-frequency
1
25
20.0
1
1
per year
HORIZONTAL

SWITCH
560
342
729
375
show-project-delay
show-project-delay
1
1
-1000

SWITCH
559
380
729
413
show-project-rejections
show-project-rejections
0
1
-1000

SWITCH
559
417
729
450
show-project-approvals
show-project-approvals
0
1
-1000

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

building institution
false
0
Rectangle -7500403 true true 0 60 300 270
Rectangle -16777216 true false 130 196 168 256
Rectangle -16777216 false false 0 255 300 270
Polygon -7500403 true true 0 60 150 15 300 60
Polygon -16777216 false false 0 60 150 15 300 60
Circle -1 true false 135 26 30
Circle -16777216 false false 135 25 30
Rectangle -16777216 false false 0 60 300 75
Rectangle -16777216 false false 218 75 255 90
Rectangle -16777216 false false 218 240 255 255
Rectangle -16777216 false false 224 90 249 240
Rectangle -16777216 false false 45 75 82 90
Rectangle -16777216 false false 45 240 82 255
Rectangle -16777216 false false 51 90 76 240
Rectangle -16777216 false false 90 240 127 255
Rectangle -16777216 false false 90 75 127 90
Rectangle -16777216 false false 96 90 121 240
Rectangle -16777216 false false 179 90 204 240
Rectangle -16777216 false false 173 75 210 90
Rectangle -16777216 false false 173 240 210 255
Rectangle -16777216 false false 269 90 294 240
Rectangle -16777216 false false 263 75 300 90
Rectangle -16777216 false false 263 240 300 255
Rectangle -16777216 false false 0 240 37 255
Rectangle -16777216 false false 6 90 31 240
Rectangle -16777216 false false 0 75 37 90
Line -16777216 false 112 260 184 260
Line -16777216 false 105 265 196 265

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

solar-generating-district
false
2
Rectangle -7500403 true false 104 195 270 270
Rectangle -16777216 true false 180 225 195 240
Rectangle -16777216 true false 150 225 165 240
Rectangle -16777216 true false 120 225 135 240
Line -7500403 false 90 135 90 195
Rectangle -7500403 true false 14 105 90 210
Polygon -13345367 true false 0 90 30 120 105 120 75 90
Rectangle -13345367 true false 45 225 45 225
Polygon -13345367 true false 150 180 180 210 225 210 195 180
Polygon -13345367 true false 90 180 120 210 165 210 135 180
Polygon -13345367 true false 210 180 240 210 285 210 255 180
Line -16777216 false 15 105 90 105
Line -16777216 false 105 195 270 195
Line -16777216 false 240 180 270 210
Line -16777216 false 180 180 210 210
Line -16777216 false 120 180 150 210
Rectangle -16777216 true false 30 135 45 150
Rectangle -16777216 true false 60 135 75 150
Rectangle -16777216 true false 30 165 45 180
Rectangle -16777216 true false 60 165 75 180
Rectangle -16777216 true false 210 225 225 240
Rectangle -16777216 true false 240 225 255 240
Line -16777216 false 60 90 90 120
Line -16777216 false 30 90 60 120

solarpark-large
false
2
Rectangle -16777216 true false 225 225 255 270
Rectangle -16777216 true false 165 225 195 270
Rectangle -16777216 true false 105 225 135 270
Rectangle -16777216 true false 45 225 75 270
Rectangle -16777216 true false 225 180 255 225
Rectangle -16777216 true false 165 180 195 225
Rectangle -16777216 true false 105 180 135 225
Rectangle -16777216 true false 45 180 75 225
Rectangle -7500403 true false 76 119 285 195
Rectangle -16777216 true false 90 135 270 165
Line -7500403 false 90 135 90 195
Line -7500403 false 120 135 120 195
Line -7500403 false 150 135 150 180
Line -7500403 false 180 135 180 195
Line -7500403 false 210 135 210 165
Line -7500403 false 240 135 240 165
Line -7500403 false 90 150 270 150
Rectangle -7500403 true false 14 153 78 195
Polygon -13345367 true false 30 180 60 210 105 210 75 180
Rectangle -13345367 true false 45 225 45 225
Polygon -13345367 true false 150 180 180 210 225 210 195 180
Polygon -13345367 true false 90 180 120 210 165 210 135 180
Polygon -13345367 true false 210 180 240 210 285 210 255 180
Polygon -13345367 true false 210 225 240 255 285 255 255 225
Polygon -13345367 true false 150 225 180 255 225 255 195 225
Polygon -13345367 true false 90 225 120 255 165 255 135 225
Polygon -13345367 true false 30 225 60 255 105 255 75 225
Line -16777216 false 45 195 270 195
Line -16777216 false 45 240 270 240
Line -16777216 false 240 225 270 255
Line -16777216 false 240 180 270 210
Line -16777216 false 180 180 210 210
Line -16777216 false 60 180 90 210
Line -16777216 false 120 180 150 210
Line -16777216 false 120 225 150 255
Line -16777216 false 60 225 90 255
Line -16777216 false 180 225 210 255

solarpark-medium
false
2
Rectangle -16777216 true false 165 225 195 270
Rectangle -16777216 true false 105 225 135 270
Rectangle -16777216 true false 225 180 255 225
Rectangle -16777216 true false 165 180 195 225
Rectangle -16777216 true false 105 180 135 225
Rectangle -16777216 true false 45 180 75 225
Rectangle -7500403 true false 120 120 285 195
Rectangle -16777216 true false 135 135 270 165
Line -7500403 false 120 135 120 195
Line -7500403 false 150 135 150 180
Line -7500403 false 180 135 180 195
Line -7500403 false 210 135 210 165
Line -7500403 false 240 135 240 165
Line -7500403 false 135 150 270 150
Polygon -13345367 true false 30 180 60 210 105 210 75 180
Rectangle -13345367 true false 45 225 45 225
Polygon -13345367 true false 150 180 180 210 225 210 195 180
Polygon -13345367 true false 90 180 120 210 165 210 135 180
Polygon -13345367 true false 210 180 240 210 285 210 255 180
Polygon -13345367 true false 150 225 180 255 225 255 195 225
Polygon -13345367 true false 90 225 120 255 165 255 135 225
Line -16777216 false 60 180 90 210
Line -16777216 false 45 195 90 195
Line -16777216 false 165 240 210 240
Line -16777216 false 225 195 270 195
Line -16777216 false 165 195 210 195
Line -16777216 false 105 195 150 195
Line -16777216 false 105 240 150 240
Line -16777216 false 240 180 270 210
Line -16777216 false 180 180 210 210
Line -16777216 false 120 180 150 210
Line -16777216 false 120 225 150 255
Line -16777216 false 180 225 210 255

solarpark-small
false
2
Rectangle -16777216 true false 225 180 255 225
Rectangle -16777216 true false 165 180 195 225
Rectangle -16777216 true false 105 180 135 225
Rectangle -16777216 true false 45 180 75 225
Rectangle -7500403 true false 165 120 285 195
Rectangle -16777216 true false 180 135 270 165
Line -7500403 false 180 135 180 195
Line -7500403 false 210 135 210 165
Line -7500403 false 240 135 240 165
Line -7500403 false 180 150 270 150
Polygon -13345367 true false 30 180 60 210 105 210 75 180
Rectangle -13345367 true false 45 225 45 225
Polygon -13345367 true false 150 180 180 210 225 210 195 180
Polygon -13345367 true false 90 180 120 210 165 210 135 180
Polygon -13345367 true false 210 180 240 210 285 210 255 180
Line -16777216 false 60 180 90 210
Line -16777216 false 45 195 90 195
Line -16777216 false 225 195 270 195
Line -16777216 false 165 195 210 195
Line -16777216 false 105 195 150 195
Line -16777216 false 240 180 270 210
Line -16777216 false 180 180 210 210
Line -16777216 false 120 180 150 210

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

windpark-large-offshore
false
2
Rectangle -13345367 true false 30 270 300 285
Rectangle -13345367 true false 15 255 285 270
Rectangle -13345367 true false 105 135 135 270
Rectangle -7500403 true false 105 75 135 75
Polygon -7500403 true false 75 195 75 225 120 165 165 105 165 75
Polygon -7500403 true false 165 195 195 195 135 150 75 105 45 105
Circle -2674135 true false 105 135 30
Polygon -13345367 true false 120 135 105 150 120 165 180 150
Rectangle -13345367 true false 210 105 240 255
Polygon -7500403 true false 180 165 180 195 225 135 270 75 270 45
Polygon -7500403 true false 270 165 300 165 240 120 180 75 150 75
Circle -2674135 true false 210 105 30
Polygon -13345367 true false 225 105 210 120 225 135 285 120
Rectangle -13791810 true false 60 270 210 285
Rectangle -13791810 true false 15 240 165 255
Rectangle -13345367 true false 0 285 345 300
Rectangle -13791810 true false 135 285 285 300

windpark-large-onshore
false
2
Rectangle -13345367 true false 105 135 135 270
Rectangle -7500403 true false 105 75 135 75
Polygon -7500403 true false 75 195 75 225 120 165 165 105 165 75
Polygon -7500403 true false 165 195 195 195 135 150 75 105 45 105
Circle -2674135 true false 105 135 30
Polygon -13345367 true false 120 135 105 150 120 165 180 150
Rectangle -13345367 true false 210 105 240 240
Polygon -7500403 true false 180 165 180 195 225 135 270 75 270 45
Polygon -7500403 true false 270 165 300 165 240 120 180 75 150 75
Circle -2674135 true false 210 105 30
Polygon -13345367 true false 225 105 210 120 225 135 285 120

windpark-medium-offshore
false
2
Rectangle -13345367 true false 30 270 300 285
Rectangle -13345367 true false 15 255 285 270
Rectangle -13345367 true false 105 135 135 270
Rectangle -7500403 true false 105 75 135 75
Polygon -7500403 true false 75 195 75 225 120 165 165 105 165 75
Polygon -7500403 true false 165 195 195 195 135 150 75 105 45 105
Circle -2674135 true false 105 135 30
Polygon -13345367 true false 120 135 105 150 120 165 180 150
Rectangle -13345367 true false 210 180 240 255
Polygon -7500403 true false 195 210 195 240 195 240 255 165 255 135
Polygon -7500403 true false 255 225 285 225 195 165 195 165 165 165
Circle -2674135 true false 210 180 30
Polygon -13345367 true false 225 180 210 195 225 210 285 195
Rectangle -13791810 true false 60 270 210 285
Rectangle -13791810 true false 15 240 165 255
Rectangle -13345367 true false 0 285 345 300
Rectangle -13791810 true false 135 285 285 300

windpark-medium-onshore
false
2
Rectangle -13345367 true false 105 135 135 270
Rectangle -7500403 true false 105 75 135 75
Polygon -7500403 true false 75 195 75 225 120 165 165 105 165 75
Polygon -7500403 true false 165 195 195 195 135 150 75 105 45 105
Circle -2674135 true false 105 135 30
Polygon -13345367 true false 120 135 105 150 120 165 180 150
Rectangle -13345367 true false 210 165 240 240
Polygon -7500403 true false 195 180 195 210 195 210 255 135 255 105
Polygon -7500403 true false 255 195 285 195 195 135 195 135 165 135
Circle -2674135 true false 210 150 30
Polygon -13345367 true false 225 150 210 165 225 180 285 165

windpark-small-offshore
false
2
Rectangle -13345367 true false 30 270 300 285
Rectangle -13345367 true false 15 255 285 270
Rectangle -13345367 true false 105 135 135 270
Rectangle -7500403 true false 105 75 135 75
Polygon -7500403 true false 75 195 75 225 120 165 165 105 165 75
Polygon -7500403 true false 165 195 195 195 135 150 75 105 45 105
Circle -2674135 true false 105 135 30
Polygon -13345367 true false 120 135 105 150 120 165 180 150
Rectangle -13791810 true false 60 270 210 285
Rectangle -13791810 true false 15 240 165 255
Rectangle -13345367 true false 0 285 345 300
Rectangle -13791810 true false 135 285 285 300

windpark-small-onshore
false
2
Rectangle -13345367 true false 105 135 135 270
Rectangle -7500403 true false 105 75 135 75
Polygon -7500403 true false 75 195 75 225 120 165 165 105 165 75
Polygon -7500403 true false 165 195 195 195 135 150 75 105 45 105
Circle -2674135 true false 105 135 30
Polygon -13345367 true false 120 135 105 150 120 165 180 150

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
NetLogo 6.1.2-beta2
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

project-externality
0.0
-0.2 0 0.0 1.0
0.0 1 2.0 2.0
0.2 0 0.0 1.0
link direction
true
0
Circle -7500403 true true 96 96 108

project-owner
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Circle -7500403 true true 96 96 108
@#$#@#$#@
0
@#$#@#$#@
