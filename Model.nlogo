extensions [csv]

;;;;;;;;;;;;;;;;;;;;;;;; GLOBALS ;;;;;;;;;;;;;;;;;;;;;;;;
globals [
  proposed-projects

  ; Timekeeping
  current-month
  current-year

  search-areas
  meetings-conducted

  projects-proposed
  projects-rejected
  urban-area-trust
  A4-area-trust
  A12-area-trust
  A15-area-trust
  A20-area-trust
  greenhouse-area-trust
  regional-trust
  trust-increase ; percentage expressed in decimals (e.g., 1.05 being 5% increase, 1.001 being 0.1% increase)
]




;;;;;;;;;;;;;;;;;;;;;;;; BREEDS & BREED VARIABLES ;;;;;;;;;;;;;;;;;;;;;;;;
breed [municipalities municipality]
breed [projects project]

municipalities-own [
  name
  inhabitants
  green-energy-openness
  political-variety
  number-informal-meetings
]

projects-own [
  active
  installed-power
  project-type
  project-size
  lifespan
  acceptance-threshold
  number-samples
  implementation-time
]


;;;;;;;;;;;;;;;;;;;;;;;; LINKS & LINK VARIABLES ;;;;;;;;;;;;;;;;;;;;;;;;
undirected-link-breed [municipality-connections municipality-connection]
directed-link-breed [project-connections project-connection]


municipality-connections-own [trust] ; trust ranges from 0 to 100, the values from the csv range in 5 discrete steps (0 to 5) which are then scaled up

project-connections-own [
  implementation-time-left ; number of ticks that still need to pass until the project becomes active
  owner ; boolean, whether the municipality is the owner of a project
  positively-affected ; boolean, whether a municipality is positively affected
  negatively-affected ; boolean, whether a municipality is negatively affected
  project-phase ; 0 = project is proposed, 1 = project is in the permission progress, 2 = project is implemented

]

;;;;;;;;;;;;;;;;;;;;;;;;  SETUP FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks

  set current-month 1
  set current-year 2021
  set meetings-conducted 0
  set projects-proposed 0
  set projects-rejected 0

  setup-municipalities
  setup-informal-network
  setup-projects
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
        set green-energy-openness item 2 data
        set political-variety item 3 data
        set number-informal-meetings 0

        set label name
        set color blue
        set shape "circle"

        ; municipalities are generated in the upper part of the screen
        let x-cor random-xcor
        let y-cor random-ycor
        ;while [x-cor <= world-width / 2] [set x-cor random-xcor]
        ;while [y-cor <= world-height / 2] [set y-cor random-ycor]
        setxy x-cor y-cor


        set size (0.5 * log inhabitants 10)
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

      ifelse random-intial-trust [
        set trust random 50
      ]

      [
        if trust = 0 [ ; in case the trust is zero, possibly override
          let municipality-trust item (municipality-id + 1) trust-ratings ; select the correct row from the trust table
          set trust (item ([who] of other-end + 1) municipality-trust * 20) ; select the correct column from the trust table
        ]
      ]
    ]
  ]

  repeat 50 [
    update-layout True
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


      ;create possible energy projects
      create-projects 1 [
        ; Variables
        set active False
        set project-type item 0 data
        set installed-power item 1 data
        set lifespan item 2 data
        set acceptance-threshold item 3 data
        set number-samples item 4 data
        set implementation-time (item 5 data) * 12 ; ticks

        let x-cor random-xcor
        let y-cor random-ycor

        set shape project-type
        set size 3
        set hidden? True
      ]

    ];end past header

    set row row + 1 ; increment the row counter for the header skip

  ]; end of while there are rows

  file-close ; make sure to close the file

end



to setup-municipality-groups

  ; Make search areas a list of lists
  set search-areas []

  ; Add different search areas based on Figure 6 of the RES 1.0 (p. 22)
  set search-areas lput (list "Urban area" (list "solarpark-urban") (turtle-set municipalities) 724) search-areas
  set search-areas lput (list "A4 area" (list "solarpark-small" "solarpark-medium" "solarpark-large" "windpark-small") (turtle-set municipalities with [member? name ["Leidschendam-Voorburg" "Rijswijk" "Delft" "Midden-Delfland" "Schiedam" "Albrandswaard" "Wassenaar"]]) 134) search-areas
  set search-areas lput (list "A12 area" (list "solarpark-small" "solarpark-medium" "solarpark-large" "windpark-small" "windpark-medium" "windpark-large") (turtle-set municipalities with [member? name ["s-Gravenhage" "Pijnacker-Nootdorp" "Zoetermeer" "Lansingerland"]]) 14) search-areas
  set search-areas lput (list "A20 area" (list "solarpark-small" "solarpark-medium" "windpark-small" "windpark-medium" "windpark-large") (turtle-set municipalities with [member? name ["Rotterdam" "Vlaardingen" "Maassluis" "Schiedam" "Capelle aan den IJssel"]]) 141) search-areas
  set search-areas lput (list "A15 area" (list "solarpark-small" "solarpark-medium" "solarpark-large" "windpark-small" "windpark-medium" "windpark-large") (turtle-set municipalities with [member? name ["Westvoorne" "Brielle" "Nissewaard" "Albrandswaard" "Barendrecht" "Ridderkerk" "Krimpen aan den IJssel"]]) 305) search-areas
  set search-areas lput (list "Greenhouse garden" (list "Solar small" "Solar medium") (turtle-set municipalities with [member? name ["Westland" "Midden-Delfland" "Pijnacker-Nootdorp" "Lansingerland" "Westvoorne"]]) 53) search-areas

end



;;;;;;;;;;;;;;;;;;;;;;;; GO FUNCTION ;;;;;;;;;;;;;;;;;;;;;;;;

to go

  ; stop simulation if year 2051 is reached
  if (current-year > end-year)[ stop ]

  ; Handle the external factors
  external-factors

  ; Do municipality actions
  ask municipalities [

    manage-projects

    communicate-informally
  ]


  ; Administrative Network
  ; distribute the meetings that are still to be conducted this year evenly across the months
  repeat round (administrative-network-meetings - meetings-conducted) / (13 - current-month) [

    set meetings-conducted meetings-conducted + 1

    conduct-meeting

  ]
  ; update the mean trust between municipalities in the region
  set regional-trust mean [trust] of municipality-connections

  ; Do visuals
  update-layout False

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
    set meetings-conducted 0
    set projects-proposed 0

    ; reset the number of informal meetings
    ask municipalities [
      set number-informal-meetings 0
    ]

    ; decrease the lifespan of all active projects by one year
    ask projects with [active] [
      set lifespan max (list 0 (lifespan - 1))
    ]
  ]


  ; In case an election happens (every four years)
  if ((current-year - 2018) mod 4) = 0 and current-month = 1 [
    ;Change political variety based on external scenarios
    output-print (word "POLITICAL: Year " current-year ": An election took place")

    ask municipalities [
      set green-energy-openness green-energy-openness * (1 + random-float 1 * (green-energy-openness-change / 100)) ; value from slider
      set political-variety  political-variety * (1 + random-float 1 * (political-variety-change / 100))  ; value from slider
    ]

  ]

  ; Propose projects
  project-proposals-generation


end


to project-proposals-generation

  ; Look at the search areas and the potential identified there (larger potential means a bigger likelihood of a project suggestion there) -> Except the urban areas, which are very small-scale projects
  ; Iterate over search areas, and make the chance of selection based on the share of total potential of a certain search area

  repeat round (total-project-proposal-frequency - projects-proposed) / (13 - current-month) [
    let search-area-selected False

    ; Randomly get a number (min 1 and max 1371, being the combined potential of the search areas
    let random-selector (random 1371) + 1

    ; Use that number to select one of the search areas (selected by the potential each search area has
    let search-area 0
    if random-selector > 0 [set search-area item 0 search-areas] ; Urban solar
    if random-selector > 724 [set search-area item 1 search-areas] ; A4 area
    if random-selector > 858 [set search-area item 2 search-areas] ; A12 area
    if random-selector > 872 [set search-area item 3 search-areas] ; A20 area
    if random-selector > 1013 [set search-area item 4 search-areas] ; A15 area
    if random-selector > 1318 [set search-area item 5 search-areas] ; Greenhouse garden areas

    ; Select the project type that is about to be implemented
    let proposed-project-type one-of item 1 search-area

    ; Get the project archetype
    ask projects with [not any? my-project-connections AND project-type = proposed-project-type] [
      ; Duplicate the project so that there are always sufficient projects
      hatch 1 [
        set hidden? True
        setxy random-xcor random-ycor
      ]

      ; pick one municipality out of the search area as a project owner
      let responsible-municipality one-of item 2 search-area

      ; create project connection to the owner
      create-project-connection-to responsible-municipality [
        set project-phase 0 ; to indicate that the project is proposed
        set implementation-time-left [implementation-time] of myself ; needs to be the lead-time from the csv
        set positively-affected True ; a municipality responsible is assumed to benefit from a project automatically
        set owner True ; set the municipality to the "responsible" municipality
        set shape "project-owner"

        if not show-projects [hide-link]

      ]


      ; Only create externalities whenever the search area is not an urban area
      if item 0 search-area != "Urban area" [

        ; assign positive and negative externatities to the other municipalities
        create-project-connections-to item 2 search-area [
          set owner False

          ; a project can have positive, negative or no externalities on another municipality
          let dice random 3
          if dice = 0 [ ; positive externalities
            set shape "project-externality"
            set positively-affected True
            set negatively-affected False
            set color 83
          ]
          if dice = 1 [ ; positive externalities
            set shape "project-externality"
            set positively-affected False
            set negatively-affected True
            set color 23
          ]

          ifelse show-externalities [show-link ] [hide-link]
        ]
      ]

      ; once projects are proposed to and taken into account by a municipality, they are shown and associated with the municipality which received it
      if show-projects [ set hidden? False  ]

    ]


  ]


end


to manage-projects

  ; Check whether there are new projects that do not have any personnel assigned
  let new-projects my-project-connections with [project-phase = 0 AND owner = True]

  if any? new-projects [

    ; Iterate over the new projects proposed
    ask new-projects [

      let project-to-discuss other-end

      ; In 50% of the cases, the city council decision is delayed
      if random-float 1 > 0.5 [
        if show-municipal-decisions [
          output-print (word "PROJECT DELAYED: " [project-type] of project-to-discuss " in " [name] of myself)
        ]
        stop
      ]

      let vote-list []

      repeat [number-samples] of project-to-discuss [
        set vote-list lput (random-normal [green-energy-openness] of myself [political-variety] of myself) vote-list
      ]

      ; Check for vote results, and check if there is capacity there (not if it's a solar urban project)
      ifelse mean vote-list >= [acceptance-threshold] of project-to-discuss AND ((count ([project-connections] of myself) with [project-phase = 0 AND owner = True]) < ([inhabitants] of myself * max-project-capacity / 10000) OR [project-type] of project-to-discuss = "solarpark-urban") [
        ; in case a project is accepted, assign one person working on the project
        if show-municipal-decisions [
          output-print (word "PROJECT ACCEPTED: " [project-type] of project-to-discuss " in " [name] of myself )
        ]

        set project-phase 1 ; to indicate that the project is in the permission procedure


        ; If accepted, the trust towards a municipality with negative externalities is reduced
        let negatively-affected-municipalities turtle-set nobody
        let positively-affected-municipalities turtle-set nobody

        ask [link-neighbors] of project-to-discuss [
          if [negatively-affected = True] of link-with project-to-discuss [
            set negatively-affected-municipalities (turtle-set negatively-affected-municipalities self)
          ]
          if [positively-affected = True] of link-with project-to-discuss [
            set positively-affected-municipalities (turtle-set positively-affected-municipalities self)
          ]
        ]

        let project-manager myself

        ; Decrease in trust with negatively affected municipalities
        ask negatively-affected-municipalities [
          ask municipality-connection-with project-manager [
            ;print (word "Trust decreased between " [name] of project-manager " (project manager) and " [name] of myself)
            set trust trust * 0.95 ; 5% descrease in trust
          ]
        ]

        ; Increase in trust with positively affected municipalities
        ask positively-affected-municipalities [
          if is-link? municipality-connection-with project-manager [ ; check, because project owner also has positive externalities
            ask municipality-connection-with project-manager [
              set trust min (list 100 (trust * 1.025)) ; 2.5% increase in trust
            ]
          ]
        ]

      ][
        ; in case a project is rejected

        if show-municipal-decisions [
          output-print (word "PROJECT REJECTED: " [project-type] of project-to-discuss " in " [name] of myself)
        ]

        ; Add to counter
        set projects-rejected projects-rejected + 1

        ask project-to-discuss [die]
      ]
    ]
  ]

  ; Work on the projects which are in phase 1 (permission phase)
  let projects-in-progress my-project-connections with [project-phase = 1 AND owner = True]
  let active-projects (turtle-set [other-end] of my-project-connections with [project-phase = 2 AND owner = True])


  ; Gain project-specific knowledge and decrease the implementation time
  ask projects-in-progress [

    ; Figure out if there are already active projects of the same type. If yes, gain 5% efficiency for each project that has already been successfully implemented
    let own-project-type [project-type] of other-end
    let experience-factor ((count active-projects with [project-type = own-project-type]) / 20)

    set implementation-time-left max list 0  (implementation-time-left - (1 + experience-factor))

    ; If no implementation time is left, set the other end to active
    if implementation-time-left = 0 [
      ; set the project phase to implementatino
      set project-phase 2

      ; set the project to active
      ask other-end [set active True]
    ]

  ]


  ; Decomission projects which lifespan has elapsed
  ask my-project-connections with [project-phase = 2 AND owner = True AND [lifespan] of other-end = 0] [
    ask other-end [
      set active False
    ]
  ]



end



to communicate-informally

  ; Exchange project-specific knowledge

  ; Get a list of own projects that are currently managed
  let own-projects []
  ask my-project-connections with [owner AND project-phase = 1 AND [project-type] of other-end != "solarpark-urban"]  [
    set own-projects lput [project-type] of other-end own-projects
  ]

  ; Get municipality's friends, select the 3 best friends
  let friend-connections max-n-of 3 my-municipality-connections [trust]
  let friends (turtle-set [other-end] of friend-connections) with [any? my-project-connections with [owner AND project-phase = 2 AND member? [project-type] of other-end own-projects]]

  ; Check if there are any friends that have already worked on a project
  if any? friends [

    ; Communicate informally with close friends
    repeat round (informal-meetings-frequency - number-informal-meetings) / (13 - current-month) [

      ; Select a close friend
      let close-friend one-of friends

      set number-informal-meetings number-informal-meetings + 1

      let percentage-shared ([trust] of municipality-connection-with close-friend) / 100

      ask one-of my-project-connections with [owner AND project-phase = 1][
        set implementation-time-left implementation-time-left - percentage-shared
      ]

      ; increase trust between the two municipalities
      ask municipality-connection-with close-friend [
        set trust min (list 100 (trust * 1.01)) ; increase by 1%
      ]

    ]
  ]






end



to conduct-meeting

  if show-regional-meetings [
    output-print (word "ADMINISTRATIVE NETWORK MEETING " meetings-conducted "/" administrative-network-meetings " started")
  ]

  foreach search-areas [
    ; store current search area in a local variable
    x -> let search-area x

    ; if any of the members of the search area have an active project, they are in the position to share their experience with others
    let experienced-municipalities (item 2 search-area) with [any? my-project-connections with [[active] of other-end]]
    let solar-experienced-municipalities (item 2 search-area) with [any? my-project-connections with [[active] of other-end AND member? [project-type] of other-end (list "solarpark-small" "solarpark-medium" "solarpark-large")]]
    let wind-experienced-municipalities (item 2 search-area) with [any? my-project-connections with [[active] of other-end AND member? [project-type] of other-end (list "windpark-small" "windpark-medium" "windpark-large")]]
    let urban-experienced-municipalities (item 2 search-area) with [any? my-project-connections with [[active] of other-end AND [project-type] of other-end = "solarpark-urban"]]

;    show (item 0 search-area)
;    show (word "experienced municipalities:" [name] of experienced-municipalities)
;    show (word "solar experienced municipalities:" [name] of solar-experienced-municipalities)
;    show (word "wind experienced municipalities:" [name] of wind-experienced-municipalities)

    let interested-municipalities (item 2 search-area) with [any? my-project-connections with [project-phase = 1]]
    let solar-interested-municipalities (item 2 search-area) with [any? my-project-connections with [project-phase = 1 AND member? [project-type] of other-end (list "solarpark-small" "solarpark-medium" "solarpark-large")]]
    let wind-interested-municipalities (item 2 search-area) with [any? my-project-connections with [project-phase = 1 AND member? [project-type] of other-end (list "windpark-small" "windpark-medium" "windpark-large")]]
    let urban-interested-municipalities (item 2 search-area) with [any? my-project-connections with [project-phase = 1 AND [project-type] of other-end = "solarpark-urban"]]
    set trust-increase 1.0005 ; trust will increase by 0.05% between experienced and interested municipalities at each meeting

;    show (word "interested municipalities:" [name] of interested-municipalities)
;    show (word "solar interested municipalities:" [name] of solar-interested-municipalities)
;    show (word "wind interested municipalities:" [name] of wind-interested-municipalities)
;    show (word "urban interested municipalities:" [name] of urban-interested-municipalities)

    if any? interested-municipalities and any? experienced-municipalities [
      ; determine the mean trust in the search area
      let search-area-trust mean [trust] of (link-set [my-municipality-connections] of interested-municipalities)

      ; store the search areas' trust means to display them
      if (item 0 search-area) = "Urban area" [set urban-area-trust search-area-trust]
      if (item 0 search-area) = "A4 area" [set A4-area-trust search-area-trust]
      if (item 0 search-area) = "A12 area" [set A12-area-trust search-area-trust]
      if (item 0 search-area) = "A15 area" [set A15-area-trust search-area-trust]
      if (item 0 search-area) = "A20 area" [set A20-area-trust search-area-trust]
      if (item 0 search-area) = "Greenhouse garden" [set greenhouse-area-trust search-area-trust]


      ; when search area is "Urban area": an information exchange occurs about urban solarparks alone
      if any? urban-experienced-municipalities AND any? urban-interested-municipalities [
        ask urban-interested-municipalities [
          ask my-project-connections [set implementation-time-left implementation-time-left - search-area-trust / 100]

          ; at each meeting, the exchange of information increases the trust between experienced and municipalities interested in the kind of project that experienced municipalities have explained
          ask my-municipality-connections with [member? other-end urban-experienced-municipalities] [set trust min (list 100 (trust * trust-increase))] ; the trust increases by 0.05%

          ; print out that information exchange happened
          if show-regional-meetings [
            output-print (word "URBAN SOLAR: Information exchange between " count urban-interested-municipalities " interested municipalities and " count urban-experienced-municipalities " experienced municipalities" )
          ]
        ]
      ]


      ; when search area is not "Urban area": an information exchange can occur about solar or wind projects
      if any? solar-experienced-municipalities AND any? solar-interested-municipalities [
        ask solar-interested-municipalities [
          ask my-project-connections [set implementation-time-left implementation-time-left - search-area-trust / 100]

          ; at each meeting, the exchange of information increases the trust between experienced and municipalities interested in the kind of project that experienced municipalities have explained
          ask my-municipality-connections with [member? other-end solar-experienced-municipalities] [set trust min (list 100 (trust * trust-increase))] ; the trust increases by 0.05%
        ]

        ; print out that information exchange happened
        if show-regional-meetings [
          output-print (word "SOLAR PROJECTS: Information exchange between " count solar-interested-municipalities " interested municipalities and " count solar-experienced-municipalities " experienced municipalities" )
        ]

      ]

      if any? wind-experienced-municipalities AND any? wind-interested-municipalities [
        ask wind-interested-municipalities [
          ask my-project-connections [set implementation-time-left implementation-time-left - search-area-trust / 100]

          ; at each meeting, the exchange of information increases the trust between experienced and municipalities interested in the kind of project that experienced municipalities have explained
          ask my-municipality-connections with [member? other-end wind-experienced-municipalities] [set trust min (list 100 (trust * trust-increase))] ; the trust increases by 0.05%
        ]

        ; print out that information exchange happened
        if show-regional-meetings [
          output-print (word "WIND PROJECTS: Information exchange between " count wind-interested-municipalities " interested municipalities and " count wind-experienced-municipalities " experienced municipalities" )
        ]

      ]

      ; in each meeting where an experienced (and thus, successful) municipality explains its project implementation, the green energy-openness of all the participating municipalities will increase
      ask interested-municipalities [set green-energy-openness min (list 100 (green-energy-openness * 1.001))] ; the green energy openness increases by 0.1%



    ]
  ]

end



;;;;;;;;;;;;;;;;;;;;;;;; DISPLAY FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;
to update-layout [first-time]


  ifelse show-municipal-network OR first-time [

    ; Color based on different trust values
    ask municipality-connections [
      show-link
      set color (50 + trust / 20)
    ]

    layout-spring municipalities municipality-connections with [trust > 0]  0.7 30 3
    layout-spring municipalities municipality-connections with [trust > 50]  0.7 20 3
  ] [
    ask municipality-connections [hide-link]
  ]

  layout-spring projects project-connections with [owner] 0.5 2 2


end

;;;;;;;;;;;;;;;;;;;;;;;; REPORTER FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;


to-report current-wind-production
  report sum [installed-power] of projects with [active AND member? project-type (list "windpark-small" "windpark-medium" "windpark-large")]
end

to-report current-solar-production
    report sum [installed-power] of projects with [active AND member? project-type (list "solarpark-small" "solarpark-medium" "solarpark-large") ]
end

to-report current-urban-production
    report sum [installed-power] of projects with [active AND project-type = "solarpark-urban" ]
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
S
NIL
NIL
1

OUTPUT
562
266
1098
389
13

MONITOR
563
214
620
259
Year
current-year
17
1
11

MONITOR
622
214
679
259
Month
current-month
17
1
11

PLOT
1105
268
1319
388
Political Overview
Green Energy Openness
Count
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"green-energy-openness" 1.0 1 -13840069 true "" "histogram [green-energy-openness] of municipalities"

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
G
NIL
NIL
1

PLOT
874
394
1202
559
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
"Active projects" 1.0 0 -14439633 true "" "plot count projects with [active = True]"
"Projects rejected" 1.0 0 -2674135 true "" "plot projects-rejected"

SLIDER
807
72
1115
105
total-project-proposal-frequency
total-project-proposal-frequency
1
25
25.0
1
1
per year
HORIZONTAL

SWITCH
1151
70
1443
103
show-municipal-decisions
show-municipal-decisions
1
1
-1000

SLIDER
807
33
1114
66
administrative-network-meetings
administrative-network-meetings
0
25
11.0
1
1
per year
HORIZONTAL

SWITCH
1151
33
1442
66
show-regional-meetings
show-regional-meetings
1
1
-1000

TEXTBOX
809
12
1120
40
Levers -------------------------------------------
11
0.0
1

TEXTBOX
1145
10
1416
52
Visuals -----------------------------------
11
0.0
1

TEXTBOX
1128
29
1143
239
|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n
11
0.0
1

SWITCH
1290
108
1444
141
show-externalities
show-externalities
1
1
-1000

SLIDER
808
109
1115
142
informal-meetings-frequency
informal-meetings-frequency
0
25
4.0
1
1
per year
HORIZONTAL

SWITCH
1153
147
1445
180
show-municipal-network
show-municipal-network
1
1
-1000

SWITCH
1153
108
1285
141
show-projects
show-projects
0
1
-1000

PLOT
1207
394
1493
559
MW implemented
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
"Wind" 1.0 0 -11221820 true "" "plot current-wind-production"
"Solar" 1.0 0 -1184463 true "" "plot current-solar-production"
"Urban" 1.0 0 -7500403 true "" "plot current-urban-production"

SLIDER
563
122
772
155
end-year
end-year
2030
2100
2080.0
5
1
NIL
HORIZONTAL

PLOT
563
394
870
559
search areas' mean trust
Tick
Mean Trust
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Urban" 1.0 0 -16777216 true "" "plot urban-area-trust"
"A4" 1.0 0 -7500403 true "" "plot A4-area-trust"
"A12" 1.0 0 -2674135 true "" "plot A12-area-trust"
"A15" 1.0 0 -955883 true "" "plot A15-area-trust"
"A20" 1.0 0 -6459832 true "" "plot A20-area-trust"
"Greenhouse" 1.0 0 -1184463 true "" "plot greenhouse-area-trust"
"Mean Trust in Region" 1.0 0 -10899396 true "" "plot regional-trust"

SWITCH
563
159
773
192
random-intial-trust
random-intial-trust
1
1
-1000

SLIDER
807
146
1114
179
green-energy-openness-change
green-energy-openness-change
-5
5
0.0
1
1
%
HORIZONTAL

SLIDER
808
183
1116
216
political-variety-change
political-variety-change
-5
5
0.0
1
1
%
HORIZONTAL

TEXTBOX
561
103
789
131
-------------------------------------
11
0.0
1

SLIDER
808
221
1119
254
max-project-capacity
max-project-capacity
0
25
9.0
1
1
per 10,000 inhabitants
HORIZONTAL

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

solarpark-urban
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

windpark-large
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

windpark-medium
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

windpark-small
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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="green-energy-openness-change">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-intial-trust">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="informal-meetings-frequency">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-externalities">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-project-proposal-frequency">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-municipal-decisions">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="administrative-network-meetings">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-project-capacity">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-municipal-network">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-regional-meetings">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-projects">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="political-variety-change">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-year">
      <value value="2080"/>
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

project-externality
0.0
-0.2 0 0.0 1.0
0.0 1 2.0 2.0
0.2 0 0.0 1.0
link direction
true
0
Circle -7500403 true true 135 135 30

project-owner
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Circle -7500403 true true 135 135 30
@#$#@#$#@
0
@#$#@#$#@
