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

  ; Double check here
  projects-agreed-in-administrative-meeting
  projects-accepted


  A4-area-trust
  A12-area-trust
  A15-area-trust
  A20-area-trust
  regional-trust

  trust-increase-in-formal-meetings ; percentage expressed in decimals (e.g., 1.05 being 5% increase, 1.001 being 0.1% increase)
  green-energy-openness-increase-in-formal-meetings ; percentage expressed in decimals (e.g., 1.05 being 5% increase, 1.001 being 0.1% increase)
  trust-increase-in-informal-meetings ; percentage expressed in decimals
  experience-scaling-factor ; integer
  n-of-most-trusted-colleagues ; integer
  percentage-delayed ; decimal
  negotiations-ending-with-agreement ; KPI, integer
  negotiations-failed-due-to-drop-out ; KPI, integer
  negotiations-failed-because-of-too-many-rounds ; KPI, integer


  ; Shocks
  shock-1-times
  shock-2-times
  shock-3-times
  shock-4-times
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
  fte
]

projects-own [
  active
  installed-power
  project-phase ; 0 = project is proposed as an issue (regional discussion); 1 = project is in permission process (local discussion), 2 = project is implemented, 3 = project is decomissioned
  project-type
  project-size
  lifespan
  acceptance-threshold
  number-samples
  implementation-time

  ; Negotiation-related attributes
  rounds-discussed ; number of rounds for how long this project is already discussed
  project-priority ; assigned to filter which projects to discuss
  offer-list ; list of all the offers and trade-offs involved in this project, including the municipality that made an offer
  negotiation-failed ; boolean, whether the municipalities managed to come to an agreement
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
  ; project-phase ; 0 = project is proposed, 1 = project is in the permission progress, 2 = project is implemented

  ; Negotiation-related attributes
  upper-threshold ; highest bound the municipality is willing to accept (numerical)
  lower-threshold ; lowest bound the municipality is willing to accept (numerical)
  concession-stepsize ; measure of how important an issue is to a municipality
  objective ; either "max" or "min", indicating in which direction a municipality would like to see the negotiation going
  my-last-offer ; attribute to save the last offer a specific municipality has made
  accept-offer ; indicator whether a municipality is willing to accept the latest offer made
  created-during-informal-communication ; indicator (True/False of weather the link was generated during an informal communication between municipalities)
  drop-out; boolean, indicates if a municipality wants to drop out of a project


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
  set projects-agreed-in-administrative-meeting 0

  set trust-increase-in-formal-meetings 1.0005 ; trust will increase by 0.05% between experienced and interested municipalities at each meeting
  set green-energy-openness-increase-in-formal-meetings 1.001 ; the green energy openness increases by 0.1%
  set trust-increase-in-informal-meetings 1.01 ; increase by 1%
  set experience-scaling-factor 20
  set n-of-most-trusted-colleagues 3
  set percentage-delayed 0.5
  set projects-accepted 0
  set projects-rejected 0
  set negotiations-ending-with-agreement 0
  set negotiations-failed-due-to-drop-out 0
  set negotiations-failed-because-of-too-many-rounds 0


  setup-municipalities
  setup-informal-network
  setup-projects
  setup-municipality-groups

  setup-shocks


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
        set fte item 4 data
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
        set offer-list (list)
        set negotiation-failed False
        set project-priority 0

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
  set search-areas lput (list "A4 area" (list "solarpark-small" "solarpark-medium" "solarpark-large" "windpark-small") (turtle-set municipalities with [member? name ["Leidschendam-Voorburg" "Rijswijk" "Delft" "Midden-Delfland" "Schiedam" "Albrandswaard" "Wassenaar"]]) 134) search-areas
  set search-areas lput (list "A12 area" (list "solarpark-small" "solarpark-medium" "solarpark-large" "windpark-small" "windpark-medium" "windpark-large") (turtle-set municipalities with [member? name ["s-Gravenhage" "Pijnacker-Nootdorp" "Zoetermeer" "Lansingerland"]]) 14) search-areas
  set search-areas lput (list "A20 area" (list "solarpark-small" "solarpark-medium" "windpark-small" "windpark-medium" "windpark-large") (turtle-set municipalities with [member? name ["Rotterdam" "Vlaardingen" "Maassluis" "Schiedam" "Capelle aan den IJssel"]]) 141) search-areas
  set search-areas lput (list "A15 area" (list "solarpark-small" "solarpark-medium" "solarpark-large" "windpark-small" "windpark-medium" "windpark-large") (turtle-set municipalities with [member? name ["Westvoorne" "Brielle" "Nissewaard" "Albrandswaard" "Barendrecht" "Ridderkerk" "Krimpen aan den IJssel"]]) 305) search-areas
  set search-areas lput (list "Greenhouse garden" (list "Solar small" "Solar medium") (turtle-set municipalities with [member? name ["Westland" "Midden-Delfland" "Pijnacker-Nootdorp" "Lansingerland" "Westvoorne"]]) 53) search-areas

end

to setup-shocks

  ; Setting for the times when they should happen. Different times can be specified in a list and are a tuple of numbers, first the year and then the month
  ; For instance, [[2021 5] [2030 9]] will create two shocks in May 2021 and in September 2030

  set shock-1-times [[2025 1] [2030 1]]
  set shock-2-times [[2035 1]]
  set shock-3-times [[2040 1]]
  set shock-4-times [[2045 1]]

end


;;;;;;;;;;;;;;;;;;;;;;;; GO FUNCTION ;;;;;;;;;;;;;;;;;;;;;;;;

to go

  ; stop simulation if year 2051 is reached
  if (current-year > end-year)[ stop ]

  ; Handle the shocks
  shock

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

    if enable-formal-meetings [conduct-meeting]


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

    ; Randomly get a number (min 1 and max 647, being the combined potential of the search areas
    let random-selector random 647

    ; Use that number to select one of the search areas (selected by the potential each search area has in the concept energy strategy)
    let search-area 0


    set search-area (ifelse-value
      random-selector < 134 [item 0 search-areas] ; A4 area
      random-selector < 148 [item 1 search-areas] ; A12 area
      random-selector < 289 [item 2 search-areas] ; A20 area
      random-selector < 594 [item 3 search-areas] ; A15 area
      random-selector < 647 [item 4 search-areas] ; Greenhouse garden areas

      )

    ; Select the project type that is about to be implemented
    let proposed-project-type one-of item 1 search-area

    ; Get the project archetype
    ask projects with [not any? my-project-connections AND project-type = proposed-project-type] [
      ; Duplicate the project so that there are always sufficient projects
      hatch 1 [
        set hidden? True
        setxy random-xcor random-ycor
      ]


      let search-area-municipalities item 2 search-area

      ; pick one municipality out of the search area as a project owner
      let responsible-municipality one-of search-area-municipalities

      ; create project connection to the owner
      create-project-connection-to responsible-municipality [
        set implementation-time-left [implementation-time] of myself ; needs to be the lead-time from the csv
        set positively-affected True ; a municipality responsible is assumed to benefit from a project automatically
        set owner True ; set the municipality to the "responsible" municipality
        set shape "project-owner"


        let stance get-stance true myself responsible-municipality

        ;print stance

        set lower-threshold item 0 stance
        set upper-threshold item 1 stance
        set concession-stepsize item 2 stance
        set objective item 3 stance
        set accept-offer False
        set drop-out False


        ; Set the initial offer
        ifelse objective = "max"[
          set my-last-offer upper-threshold
        ][
          set my-last-offer lower-threshold
        ]

        if not show-projects [hide-link]

      ]

      ; Remove the project owner from possible externalally affected municipalities
      set search-area-municipalities turtle-set remove responsible-municipality (list search-area-municipalities)


      ; assign positive and negative externatities to the other municipalities

      create-project-connections-to n-of 2 search-area-municipalities [
        set owner False
        set created-during-informal-communication False

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

       ; Prepare for the negotiation
        let stance get-stance false myself other-end

        ;print stance

        set lower-threshold item 0 stance
        set upper-threshold item 1 stance
        set concession-stepsize item 2 stance
        set objective item 3 stance
        set accept-offer False
        set drop-out False


        ; Set the initial offer
        ifelse objective = "max"[
          set my-last-offer upper-threshold
        ][
          set my-last-offer lower-threshold
        ]


        ifelse show-externalities [show-link ] [hide-link]
      ]


      ; once projects are proposed to and taken into account by a municipality, they are shown and associated with the municipality which received it
      if show-projects [ set hidden? False  ]

    ]


  ]


end







to manage-projects

  ; PHASE 2 PROJECTS ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  ; Focus on the projects in phase 2 that are not active yet (i.e., projects that were agreed at the regional level and passed the voting at the municipality level, and now need to be implemented)
  let projects-agreed-and-voted-connections my-project-connections with [[project-phase] of other-end = 2 AND [active] of other-end = False AND owner = True]
  let projects-agreed-and-voted turtle-set [other-end] of projects-agreed-and-voted-connections

  ; Decrease a project implementation time, as a month has elapsed
  ask projects-agreed-and-voted [
    set implementation-time implementation-time - 1
  ]

  ; Identify projects of the same kind that the municipality has already implemented. The municipality will gain experience from the execution of these projects for the implementation of the new ones.
  let active-projects (turtle-set [other-end] of my-project-connections with [[project-phase] of other-end = 2 AND [active] of other-end = True AND owner = True])

  ; Gain project-specific knowledge from other projects of the same type. This means a decrease in the projects' implementation time
  ; Figure out if there are already active projects of the same type (by counting them). If there are some, gain 5% efficiency for each project that has already been successfully implemented (i.e., the active projects)
  let own-project-type [project-type] of projects-agreed-and-voted

  let experience-factor ((count active-projects with [project-type = own-project-type]) / experience-scaling-factor)
  ask projects-agreed-and-voted-connections [
    set implementation-time-left max list 0  (implementation-time-left - (1 + experience-factor))

    ; If no implementation time is left, set the project to active
    if implementation-time-left = 0 [
      ask other-end [
        set active True
      ]
    ]
  ]

  ; Decomission (active) projects in phase 2 whose lifespan has elapsed.
  ask my-project-connections with [[project-phase] of other-end = 2 AND owner = True AND [lifespan] of other-end = 0] [ ; there is no need to select active projects, as only active ones are subject to a decrease in lifespan
    ask other-end [
      set active False
    ]
  ]


  ; PHASE 1 PROJECTS ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  ; Check whether there are projects in phase 1 (i.e., projects that were agreed at the regional level and that now have to be discussed and voted at the municipality level)
  let projects-agreed-connections my-project-connections with [[project-phase] of other-end = 1 AND owner = True]
  let projects-agreed turtle-set [other-end] of projects-agreed-connections

  if any? projects-agreed-connections [

    ; In 50% of the cases, the city council decision is delayed
    if random-float 1 > percentage-delayed [
      if show-municipal-decisions [
        output-print (word "PROJECT DELAYED: " [project-type] of projects-agreed " in " [name] of self)
      ]
      stop ; in this way these selected projects do not undergo the following commands of this procedure
    ]


    ; For the other projects not being delayed, depending on the size of the project to be discussed, a specific number of actors (number-samples) is called to express their opinion on the project
    let vote-list []

    repeat item 0 [number-samples] of projects-agreed [ ;number-samples is a list with only one value in it
      set vote-list lput (random-normal [green-energy-openness] of self [political-variety] of self) vote-list
    ]

    ; Check for vote results, and (except in the case the project is a solar urban one) check if there is personnels' capacity in that municipality
    ifelse mean vote-list >= item 0 [acceptance-threshold] of projects-agreed AND ((count  my-project-connections with [[project-phase] of other-end > 0 AND owner = True]) < ([inhabitants] of self * max-project-capacity / 10000) OR [project-type] of projects-agreed = "solarpark-urban") [

      ; In case a project is accepted:
      ; print it in the output screen
      if show-municipal-decisions [
        output-print (word "PROJECT ACCEPTED: " [project-type] of projects-agreed " in " [name] of self )
      ]
      ; move the project to the next phase (i.e., phase 2)
      ; print projects-agreed
      ask projects-agreed [
        set project-phase 2
      ]

      ; decrease the trust with the municipalities negatively affected by the project just approved
      ;so, first, identify the project-owning municipality, namely the caller of this procedure
      let project-owning-municipality self

      ;identify the municipalities that are positively affected by the project just agreed upon at the regional level (and accepted at the municipal one)
      ask projects-agreed [
        let positively-affected-municipalities turtle-set [other-end] of my-project-connections with [positively-affected = True]

        ;and increase the trust between the positively affected municipalities (other than the project-owning municipality) and the project-owning municipality
        ask positively-affected-municipalities [
          if self != project-owning-municipality [
            ask municipality-connection-with project-owning-municipality [
              set trust min (list 100 (trust * 1.025)) ; 2.5% increase in trust up to a maximum of 100
            ]
          ]
        ]
      ]

      ;then, itendify the municipalities that are negatively affected by the project just agreed upon at the regional level (and accepted at the municipal one)
      ask projects-agreed [
        let negatively-affected-municipalities turtle-set [other-end] of my-project-connections with [negatively-affected = True]

        ; decrease the trust between the negatively affected municipalities and the project-owning municipality
        ask negatively-affected-municipalities [
          ask municipality-connection-with project-owning-municipality [
            set trust trust * 0.95 ; 5% decrease in trust
          ]
        ]
      ]

    ][
      ; In case a project is rejected:
      ; print it in the output screen
      if show-municipal-decisions [
        output-print (word "PROJECT REJECTED: " [project-type] of projects-agreed " in " [name] of self)
      ]

      ; Add to counter
      set projects-rejected projects-rejected + 1

      ask projects-agreed [die]
    ]
  ]

end



to communicate-informally

  ; Exchange project-specific knowledge

  ; Get a list of the own projects that were agreed at the regional level and approved in the voting of the municipality level, and that are still undergoing implementation (they are not active yet)
  let own-projects []
  ask my-project-connections with [owner AND [project-phase] of other-end = 2 AND [active] of other-end = False AND [project-type] of other-end != "solarpark-urban"]  [
    set own-projects lput [project-type] of other-end own-projects
  ]

  ; Get municipality's friends, select the 3 best friends who have already finished a project of the same kind
  let friend-connections max-n-of n-of-most-trusted-colleagues my-municipality-connections [trust]
  let friends (turtle-set [other-end] of friend-connections) with [any? my-project-connections with [owner AND [active] of other-end = True AND member? [project-type] of other-end own-projects]]

  ; Check if there are any friends that have already finished working on a project of that same kind
  if any? friends [

    repeat round (informal-meetings-frequency - number-informal-meetings) / (13 - current-month) [

      ; Select a close friend
      let close-friend one-of friends

      set number-informal-meetings number-informal-meetings + 1
      ; Idenfity how much information will be shared about the project implemenation process, proportionally to the trust between the two municipalities
      let percentage-shared ([trust] of municipality-connection-with close-friend) / 100

      ; Communicate informally with those close friends, so that the implementation time of my own projects is decreased
      let project-connections-to-be-helped my-project-connections with [owner AND [project-phase] of other-end = 2 AND [active] of other-end = False AND [project-type] of other-end != "solarpark-urban"]
      if any? project-connections-to-be-helped [
        ask one-of project-connections-to-be-helped [
          set implementation-time-left implementation-time-left - percentage-shared
        ]
      ]

      ; increase trust between the two municipalities
      ask municipality-connection-with close-friend [
        set trust min (list 100 (trust * trust-increase-in-informal-meetings)) ; increase by 1%
      ]
    ]
  ]

  ; when a municipality who is the owner of a project is also discussing it in the administrative network meetings (project phase = 0 and project priority is > 0)
  ; it forms a coalition with other municipalities with whom it developed a high trust until then. Concretely, this means that their upper and lower thresholds
  ; for the negotiation on that project become aligned.
  if [owner] of my-project-connections = True and [project-phase] of my-project-connections = 0 and [project-priority] of my-project-connections  > 0 [

    ; identify the project being discussed
    let project-discussed [other-end] of my-project-connections


    ; identify the project owner's most trusted friends
    let owner-friend-connections max-n-of n-of-most-trusted-colleagues my-municipality-connections [trust]
    let owner-friends (turtle-set [other-end] of owner-friend-connections) with [any? my-project-connections with [owner AND [project-phase] of other-end = 2 AND member? [project-type] of other-end own-projects]]

    if any? owner-friends [
      ask owner-friends [

        ; identify friends' projects
        let owner-friend-projects [other-end] of my-project-connections

        ; The friends need to create a link with the project if there isn't already a link between the friends and the project being discussed
        if not member? project-discussed owner-friend-projects [
          create-project-connections-from project-discussed [
              set owner False
              set created-during-informal-communication True]
        ]

        ; select the link between the friends and the project being discussed
        let project-discussed-connection my-project-connections with [other-end = project-discussed]

        ; if the friends were not negatively affected by a project being discussed
        if [negatively-affected] of project-discussed-connection = False [
          ask [other-end] of project-discussed-connection [
            output-print "THRESHOLDS ALIGN"

            ; align thresholds of friends to the project owner's ones
            set upper-threshold [upper-threshold] of project-discussed
            set lower-threshold [lower-threshold] of project-discussed
          ]
        ]
      ]
    ]
  ]



end





to conduct-meeting

  ; Print out meetings number
  if show-regional-meetings [
    output-print (word "ADMINISTRATIVE NETWORK MEETING " meetings-conducted "/" administrative-network-meetings " started")
  ]


  ; Iterate over several meeting rounds
  repeat rounds-per-meeting [

    ; Select the project to be discussed
    let discussed-project select-project-to-be-discussed

    ; Abort if there is no project to be discussed
    if (discussed-project != 0) and (discussed-project != nobody) [

      ask discussed-project [

        ; Increase counter for round discussed
        set rounds-discussed rounds-discussed + 1

        ; Iterate over all municipalities involved
        ask my-project-connections [

          ; Get the last offer and the last offering municipality from the offer list
          let latest-offer -1
          let latest-municipality -1

          if length [offer-list] of myself > 0 [
            set latest-offer item 1 last [offer-list] of myself
            set latest-municipality item 0 last [offer-list] of myself
          ]


          ; CASE 1 - Make an offer, if no offer is made yet ------------------------------------------------------------------------------------------------------------
          if latest-offer = -1 [
            let offer 0
            ifelse objective = "min" [ set offer lower-threshold] [set offer upper-threshold ]

            set my-last-offer offer
            make-new-offer [who] of myself (list [who] of other-end offer)

            set latest-municipality [who] of other-end
            set latest-offer offer

            ; Print
            if show-regional-meetings [output-print (word [name] of other-end " made a first offer: " offer " MW")]

          ]


          ; CASE 2 - Accept the previous offer, only if the offer is in "reach" (not to far away from the current offer and within the thresholds ------------------------
          if (latest-offer >= lower-threshold) and (latest-offer <= upper-threshold) [

            let agreed? False

            ; Check the objective and agree based on that
            if (objective = "min" and latest-offer <= my-last-offer) or (objective = "max" and latest-offer >= my-last-offer) or (abs (my-last-offer - latest-offer) < (agreement-factor * concession-stepsize)) [
              set accept-offer True
              set agreed? True
              set my-last-offer latest-offer
              set latest-municipality [who] of other-end
            ]

            ; Print
            if show-regional-meetings and agreed? and (latest-municipality != [who] of other-end) [output-print (word [name] of other-end " agrees to the offer.")]
          ]



          ; CASE 3 - Make a counter-offer, if the latest offer is not from myself and made a different offer -------------------------------------------------------------------
          if (latest-municipality != [who] of other-end) and (latest-municipality >= 0) and (latest-offer != my-last-offer)[

            let offer my-last-offer ; Get the last offer of the municipality
            ifelse objective = "min" [
              ; Check if concession would cross the threshold
              set offer min (list (offer + concession-stepsize) upper-threshold) ][
              set offer max (list (offer - concession-stepsize) lower-threshold) ]

            set my-last-offer offer
            make-new-offer [who] of myself (list [who] of other-end offer)

            set latest-municipality [who] of other-end

            ; Print
            if show-regional-meetings [output-print (word [name] of other-end " made a counter offer: " offer " MW")]
          ]



          ; CASE 4 - Drop out of the project -----------------------------------------------------------------------------------------------------------------------------

          if (latest-municipality != [who] of other-end) and (latest-offer = my-last-offer) and accept-offer = False [
            set drop-out True

            output-print (word "My last offer: " my-last-offer)

            ; Print
            if show-regional-meetings [output-print (word [name] of other-end " has dropped out of the negotiations")]
          ]
        ]

        ; On a project level, check for different cases
        ; Case 1: Did everyone accept?
        if not member? False [accept-offer] of my-project-connections [

          set negotiations-ending-with-agreement negotiations-ending-with-agreement + 1

          ; Check if there was no windpark with 0 megawatts accepted
          ifelse item 1 last offer-list <= 0 [
            if show-regional-meetings [output-print (word "An agreement has been reached that no wind shall be implemented " project-type " in " [[name] of other-end] of my-project-connections with [owner = True])]

            set project-priority 0
            set negotiation-failed True
            set projects-rejected projects-rejected + 1

          ][
            if show-regional-meetings [output-print (word "An agreement has been reached on " project-type " in " [[name] of other-end] of my-project-connections with [owner = True])]

            set project-priority 0
            set project-phase 1

            change-trust who 0.5

            set projects-accepted projects-accepted + 1
          ]


        ]


        ; Case 2: Did anyone drop out?
        if member? True [drop-out] of my-project-connections [

          if show-regional-meetings [output-print (word "Negotiation failed because someone dropped out after " rounds-discussed " rounds in " project-type " (Project ID " who ")")]

          fail-negotiation who
          set projects-rejected projects-rejected + 1
          set negotiations-failed-due-to-drop-out negotiations-failed-due-to-drop-out + 1


        ]



        ; Case 3: Did the negotiation run for too long?
        if max-rounds-before-failed <= rounds-discussed [
          if show-regional-meetings [output-print (word "Negotiation failed due to too many rounds: " rounds-discussed " Rounds for " project-type " (Project ID " who ")")]

          fail-negotiation who
          set projects-rejected projects-rejected + 1
          set negotiations-failed-because-of-too-many-rounds negotiations-failed-because-of-too-many-rounds + 1

        ]

      ]
    ]
    ask project-connections with [created-during-informal-communication = True] [die]
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

    let interested-municipalities (item 2 search-area) with [any? my-project-connections with [[project-phase] of other-end = 1]]
    let solar-interested-municipalities (item 2 search-area) with [any? my-project-connections with [[project-phase] of other-end = 1 AND member? [project-type] of other-end (list "solarpark-small" "solarpark-medium" "solarpark-large")]]
    let wind-interested-municipalities (item 2 search-area) with [any? my-project-connections with [[project-phase] of other-end = 1 AND member? [project-type] of other-end (list "windpark-small" "windpark-medium" "windpark-large")]]
    let urban-interested-municipalities (item 2 search-area) with [any? my-project-connections with [[project-phase] of other-end = 1 AND [project-type] of other-end = "solarpark-urban"]]

;    show (word "interested municipalities:" [name] of interested-municipalities)
;    show (word "solar interested municipalities:" [name] of solar-interested-municipalities)
;    show (word "wind interested municipalities:" [name] of wind-interested-municipalities)
;    show (word "urban interested municipalities:" [name] of urban-interested-municipalities)

    if any? interested-municipalities and any? experienced-municipalities [
      ; determine the mean trust in the search area
      let search-area-trust mean [trust] of (link-set [my-municipality-connections] of interested-municipalities)

      ; store the search areas' trust means to display them
      if (item 0 search-area) = "A4 area" [set A4-area-trust search-area-trust]
      if (item 0 search-area) = "A12 area" [set A12-area-trust search-area-trust]
      if (item 0 search-area) = "A15 area" [set A15-area-trust search-area-trust]
      if (item 0 search-area) = "A20 area" [set A20-area-trust search-area-trust]


      ; when search area is "Urban area": an information exchange occurs about urban solarparks alone
      if any? urban-experienced-municipalities AND any? urban-interested-municipalities [
        ask urban-interested-municipalities [
          ask my-project-connections [set implementation-time-left implementation-time-left - search-area-trust / 100]

          ; at each meeting, the exchange of information increases the trust between experienced and municipalities interested in the kind of project that experienced municipalities have explained
          ask my-municipality-connections with [member? other-end urban-experienced-municipalities] [set trust min (list 100 (trust * trust-increase-in-formal-meetings))] ; the trust increases by 0.05%

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
          ask my-municipality-connections with [member? other-end solar-experienced-municipalities] [set trust min (list 100 (trust * trust-increase-in-formal-meetings))] ; the trust increases by 0.05%
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
          ask my-municipality-connections with [member? other-end wind-experienced-municipalities] [set trust min (list 100 (trust * trust-increase-in-formal-meetings))] ; the trust increases by 0.05%
        ]

        ; print out that information exchange happened
        if show-regional-meetings [
          output-print (word "WIND PROJECTS: Information exchange between " count wind-interested-municipalities " interested municipalities and " count wind-experienced-municipalities " experienced municipalities" )
        ]

      ]

      ; in each meeting where an experienced (and thus, successful) municipality explains its project implementation, the green energy-openness of all the participating municipalities will increase
      ask interested-municipalities [set green-energy-openness min (list 100 (green-energy-openness * green-energy-openness-increase-in-formal-meetings))] ; the green energy openness increases by 0.1%



    ]
  ]

end




to make-new-offer [project-id offer]

  ask project project-id [

    ; Append the offer to the offer-list
    set offer-list lput offer offer-list

    ; Reset all agreements to the offer
    ask my-project-connections [
      set accept-offer False
    ]
  ]

end


to-report get-stance [project-owner? a-project my-municipality]

  let concession-step 0
  let upper-threshold 0
  let lower-threshold 0
  let objective ""

  let inh [inhabitants] of my-municipality
  let geo [green-energy-openness] of my-municipality

  ; Determine the concession step and the range
  if member? "wind" [project-type] of a-project [

    let concession-factor (0.000001642036 * inh + 0.9770115)
    set concession-factor round concession-factor
    set concession-step (10 / concession-factor) ; 5 or 10MW, which equals to one or two windturbines

    ; All municipalities will have 0 as a lower threshold for wind projects
    set lower-threshold 0

    ; Desired number of windmills is the largest windpark (6 turbines) in case of a high green energy openness and 0 windmills in case of a low green energy openness
    let number-windmills round (6 * (geo / 100))

    set upper-threshold (number-windmills * 5) ; 5MW per windmill

  ]

  ; In case the project is solar
  if member? "solar" [project-type] of a-project [

    ; original maximum concession step is 150KW (50 percentile of  solar projects implemented in 2019 in Zuid Holland)
    set concession-step 0.15 ; 90KW negotiation size

    ; Inhabitants influence the concession stepsize in a linear way
    ; Linear interpolation based on the smallest and biggest municipality
    ; Assuption: Larger municipalities have more (soft) power to push through their interest and are thus willing to make less concessions
    ; Linear function returns values between 1 (smallest municipality) and 2 (largest municipality)
    let concession-factor (0.000001642036 * inh + 0.9770115)

    ; High and low green energy openness concession influece is modelled with a parabola
    ; A very low and a very high green energy openness will result in less concessions due to strong believes in a certain direction.
    ; Function is a parabola that returns 2 in case the green energy openness is 0 or 100; and 1 in case the green energy openness is 50
    set concession-factor concession-factor * (2 - 0.04 * geo + 0.0004 * geo)

    ; Set the final concession step based on the maximal concession step and the factor as calculated by the two formulas above.
    set concession-step concession-step / concession-factor


    ; Determine the range
    let max-solar-project-size 5

    ifelse project-owner? [
      set lower-threshold 0
      set upper-threshold round (max-solar-project-size * (geo / 100))
    ][
      ; For non project owners, at least a small solar park should be implemented
      set lower-threshold 0.06
      set upper-threshold 0.06 + precision ((max-solar-project-size - 0.06) * (geo / 100)) 2
    ]
  ]


  ; Determine the objective
  ; If a project owner is the municipality
  ifelse project-owner? [
    ifelse member? "solar" [project-type] of a-project [

      ; In case green energy openness is greater than 33%, try to maximize your range, otherwise try to minimize it
      ifelse geo > 33[
        set objective "max"
      ][
        set objective "min"
      ]
    ][
      ; In case the project is about wind, always try to minimize the impact
      set objective "min"
    ]

  ][
    ; If a project owner is not the municipality, always try to maximize the renewable energy projects of other municipalities
    set objective "max"
  ]


  ; Determine the range



  report (list lower-threshold upper-threshold concession-step objective)

end



to-report select-project-to-be-discussed

  ; In case there aren't any projects that are prioritized
  if not any? projects with [project-priority > 0 and project-phase = 0] [

    if any? projects with [project-phase = 0 AND any? my-project-connections and negotiation-failed = False] [
      ask one-of projects with [project-phase = 0 AND any? my-project-connections and negotiation-failed = False] [
        set project-priority 100

        if show-regional-meetings [output-print (word "A new project started to be discussed: " self " (" project-type ")")]
      ]
    ]
  ]

  report one-of projects with [project-priority > 0 and project-phase = 0]

end



to change-trust [project-id amount]

  ask project project-id [

    ; Decrease trust between all parties involved
    let municipalities-involved turtle-set [other-end] of my-project-connections

    ; create a list of municipality connections
    let municipality-trust-connections (list)

    ask municipalities-involved [
      ; Iterate over all municipality connections
      ask turtle-set [other-end] of my-municipality-connections [
        ; Decrease trust in case the
        if member? self municipalities-involved [

          set municipality-trust-connections lput municipality-connection-with myself municipality-trust-connections

        ]
      ]
    ]

    ; Remove duplicate links in the list
    set municipality-trust-connections remove-duplicates municipality-trust-connections

    ; Change the trust value
    foreach municipality-trust-connections [
      x -> ask x [
        set trust trust + amount

        let connected-municipalities (list [name] of both-ends)

        if amount > 0 and show-trust-changes [
          output-print (word "Trust increase between " connected-municipalities)
        ]

        if amount < 0 and show-trust-changes [
          output-print (word "Trust decrease between " connected-municipalities)
        ]
      ]
    ]
  ]


end


to fail-negotiation [project-id]

  ask project project-id[
    set negotiation-failed True
    set project-priority 0
    set hidden? True
  ]

  change-trust project-id -0.5

end



to shock

  ; Handle shock 1 - Drop in Trust, in case it is enabled ----------------------------------------------------------
  if Shock-1-Trust-drop [

    ; Variable that is set true if for whatever reason this tick shock 1 will happen
    let shock-now False

    ; Check if the shock is scheduled or will happen at a random time
    ifelse S1-Time = "At given times" [
      ; In case times are scheduled, iterate over the shock timelist as specified in the procedure setup-shocks
      foreach shock-1-times [x -> if current-year = item 0 x and current-month = item 1 x [ set shock-now True ]]]

    [
      ; In case the shock is at random times, chheck if it's gonna happen randomly
      let random-time random-float 100
      if random-shock-probability > random-time [set shock-now True ]
    ]

    if shock-now [
      ; Execute Shock
      ask municipality-connections [
        set trust 0.1 * trust ; decrease trust to 10% of the previous value
      ]

      output-print (word "SHOCK: Shock 1 (reduce trust) happened in " current-year " " current-month)
    ]
  ]



  ; Handle shock 2 - Search area frequency, in case it is enabled ----------------------------------------------------------
  if Shock-2-Meeting-frequency [

    ; Variable that is set true if for whatever reason this tick shock 1 will happen
    let shock-now False

    ; Check if the shock is scheduled or will happen at a random time
    ifelse S2-Time = "At given times" [
      ; In case times are scheduled, iterate over the shock timelist as specified in the procedure setup-shocks
      foreach shock-2-times [x -> if current-year = item 0 x and current-month = item 1 x [ set shock-now True ]]]

    [
      ; In case the shock is at random times, chheck if it's gonna happen randomly
      let random-time random-float 100
      if random-shock-probability > random-time [set shock-now True ]
    ]

    if shock-now [
      ; Execute Shock
      set administrative-network-meetings 1 ; Set the administrative network meetings to one

      output-print (word "SHOCK: Shock 2 (Meeting-frequency) happened in " current-year " " current-month)
    ]
  ]


  ; Handle shock 3 - Change in green energy opennness, in case it is enabled ----------------------------------------------------------
  if Shock-3-Green-energy-openness [

    ; Variable that is set true if for whatever reason this tick shock 1 will happen
    let shock-now False

    ; Check if the shock is scheduled or will happen at a random time
    ifelse S3-Time = "At given times" [
      ; In case times are scheduled, iterate over the shock timelist as specified in the procedure setup-shocks
      foreach shock-3-times [x -> if current-year = item 0 x and current-month = item 1 x [ set shock-now True ]]]

    [
      ; In case the shock is at random times, chheck if it's gonna happen randomly
      let random-time random-float 100
      if random-shock-probability > random-time [set shock-now True ]
    ]

    if shock-now [
      ; Execute Shock
      ask municipalities [
        set green-energy-openness 0.5 * green-energy-openness ; Decrease all of the green energy opennesses by 50%

      ]

      output-print (word "SHOCK: Shock 3 (Green energy openness) happened in " current-year " " current-month)
    ]
  ]


  ; Handle shock 4 - Change in political variety, in case it is enabled ----------------------------------------------------------
  if Shock-4-Political-variety [

    ; Variable that is set true if for whatever reason this tick shock 1 will happen
    let shock-now False

    ; Check if the shock is scheduled or will happen at a random time
    ifelse S4-Time = "At given times" [
      ; In case times are scheduled, iterate over the shock timelist as specified in the procedure setup-shocks
      foreach shock-4-times [x -> if current-year = item 0 x and current-month = item 1 x [ set shock-now True ]]]

    [
      ; In case the shock is at random times, chheck if it's gonna happen randomly
      let random-time random-float 100
      if random-shock-probability > random-time [set shock-now True ]
    ]

    if shock-now [
      ; Execute Shock
      ask municipalities [
        set political-variety 0.5 * political-variety ; Decrease all of the political variety values by 50%

      ]

      output-print (word "SHOCK: Shock 4 (Political variety) happened in " current-year " " current-month)
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

to-report get-desired-range [municipality-id type-of-project owner-of-project]

  let selected-municipality municipality municipality-id
  report [inhabitants] of selected-municipality
end

to-report negative-externalities
  report count project-connections with [negatively-affected = True]
end

to-report positive-externalities
  report count project-connections with [positively-affected = True]
end

to-report average-degree-centrality
  let degree-centrality 0
  ask municipalities [
    set degree-centrality sum [trust] of my-municipality-connections
  ]
  report degree-centrality / count municipality-connections
end
@#$#@#$#@
GRAPHICS-WINDOW
13
150
559
697
-1
-1
7.08
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
15
20
228
53
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
572
374
1108
697
13

MONITOR
15
101
72
146
Year
current-year
17
1
11

MONITOR
81
102
138
147
Month
current-month
17
1
11

PLOT
1122
375
1336
520
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
16
58
227
91
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
1119
531
1619
696
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
"Projects accepted in formal meetings" 1.0 0 -16777216 true "" "plot projects-accepted"
"Active projects" 1.0 0 -14439633 true "" "plot count projects with [active = True]"
"Projects rejected" 1.0 0 -2674135 true "" "plot projects-rejected"

SLIDER
585
182
871
215
total-project-proposal-frequency
total-project-proposal-frequency
1
25
16.0
1
1
per year
HORIZONTAL

SWITCH
1757
92
2049
125
show-municipal-decisions
show-municipal-decisions
1
1
-1000

SLIDER
938
220
1243
253
administrative-network-meetings
administrative-network-meetings
0
25
1.0
1
1
per year
HORIZONTAL

SWITCH
1757
55
2048
88
show-regional-meetings
show-regional-meetings
0
1
-1000

TEXTBOX
939
36
1250
64
Levers -------------------------------------------
11
0.0
1

TEXTBOX
1751
32
2022
74
Visuals -----------------------------------
11
0.0
1

TEXTBOX
1269
61
1284
327
|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|
11
0.0
1

SWITCH
1895
210
2049
243
show-externalities
show-externalities
1
1
-1000

SLIDER
936
61
1243
94
informal-meetings-frequency
informal-meetings-frequency
0
25
11.0
1
1
per year
HORIZONTAL

SWITCH
1757
131
2048
164
show-municipal-network
show-municipal-network
0
1
-1000

SWITCH
1758
210
1890
243
show-projects
show-projects
0
1
-1000

PLOT
1627
377
1913
693
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

SLIDER
585
64
871
97
end-year
end-year
2030
2100
2070.0
5
1
NIL
HORIZONTAL

PLOT
1352
375
1620
525
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
"Mean Trust in Region" 1.0 0 -10899396 true "" "plot regional-trust"

SWITCH
585
272
871
305
random-intial-trust
random-intial-trust
0
1
-1000

SLIDER
584
103
872
136
green-energy-openness-change
green-energy-openness-change
-5
5
2.0
1
1
%
HORIZONTAL

SLIDER
585
142
870
175
political-variety-change
political-variety-change
-10
10
4.0
1
1
%
HORIZONTAL

TEXTBOX
585
36
900
64
Uncertainties -------------------------------------
11
0.0
1

SLIDER
933
142
1243
175
max-project-capacity
max-project-capacity
0
50
25.0
1
1
per 10,000 inhabitants
HORIZONTAL

SWITCH
584
308
871
341
enable-formal-meetings
enable-formal-meetings
0
1
-1000

SLIDER
935
99
1243
132
search-area-meetings
search-area-meetings
0
50
19.0
1
1
per year
HORIZONTAL

SLIDER
938
261
1245
294
rounds-per-meeting
rounds-per-meeting
0
15
4.0
1
1
NIL
HORIZONTAL

SLIDER
584
221
872
254
agreement-factor
agreement-factor
1
10
6.0
1
1
NIL
HORIZONTAL

SWITCH
1757
170
2048
203
show-trust-changes
show-trust-changes
1
1
-1000

TEXTBOX
938
194
1202
236
Negotiations Levers ------------------
11
0.0
1

SLIDER
937
303
1243
336
max-rounds-before-failed
max-rounds-before-failed
0
25
24.0
1
1
NIL
HORIZONTAL

TEXTBOX
286
34
546
76
Shocks ------------------------------
11
0.0
1

TEXTBOX
896
64
911
330
|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|
11
0.0
1

TEXTBOX
551
54
566
124
|\n|\n|\n|\n|\n
11
0.0
1

TEXTBOX
1296
37
1564
79
Shocks -----------------------------------
11
0.0
1

TEXTBOX
1729
60
1744
326
|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|\n|
11
0.0
1

SWITCH
1297
70
1550
103
Shock-1-Trust-drop
Shock-1-Trust-drop
1
1
-1000

SWITCH
1297
119
1550
152
Shock-2-Meeting-frequency
Shock-2-Meeting-frequency
1
1
-1000

SWITCH
1296
168
1550
201
Shock-3-Green-energy-openness
Shock-3-Green-energy-openness
1
1
-1000

SWITCH
1298
219
1550
252
Shock-4-Political-variety
Shock-4-Political-variety
1
1
-1000

CHOOSER
1569
63
1707
108
S1-Time
S1-Time
"Random" "At given times"
0

CHOOSER
1569
114
1707
159
S2-Time
S2-Time
"Random" "At given times"
1

CHOOSER
1569
165
1707
210
S3-Time
S3-Time
"Random" "At given times"
0

CHOOSER
1569
214
1707
259
S4-Time
S4-Time
"Random" "At given times"
1

SLIDER
1297
279
1710
312
random-shock-probability
random-shock-probability
0
100
8.5
0.5
1
%
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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="outcomes_with_and_without_formal_meetings" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>current-wind-production</metric>
    <metric>current-solar-production</metric>
    <metric>current-urban-production</metric>
    <metric>count project-connections with [owner = True]</metric>
    <metric>count projects with [active = True]</metric>
    <metric>projects-rejected</metric>
    <metric>regional-trust</metric>
    <steppedValueSet variable="random-seed" first="0" step="1" last="5"/>
    <enumeratedValueSet variable="green-energy-openness-change">
      <value value="-5"/>
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-intial-trust">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="informal-meetings-frequency">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-externalities">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-project-proposal-frequency">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-municipal-decisions">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="administrative-network-meetings">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-project-capacity">
      <value value="12"/>
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
      <value value="-5"/>
      <value value="0"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-year">
      <value value="2050"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable-formal-meetings">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="search-area-meetings">
      <value value="31"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-intial-trust">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable-shocks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-municipal-decisions">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-meeting">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agreement-factor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-regional-meetings">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="political-variety-change">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="green-energy-openness-change">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-trust-changes">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable-formal-meetings">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="informal-meetings-frequency">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-project-proposal-frequency">
      <value value="17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-externalities">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="administrative-network-meetings">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-project-capacity">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-rounds-before-failed">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-municipal-network">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-year">
      <value value="2090"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-projects">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="123" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <steppedValueSet variable="search-area-meetings" first="1" step="30" last="5"/>
    <enumeratedValueSet variable="random-intial-trust">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable-shocks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-municipal-decisions">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-meeting">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agreement-factor">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-regional-meetings">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="political-variety-change">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="green-energy-openness-change">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-trust-changes">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable-formal-meetings">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="informal-meetings-frequency">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-project-proposal-frequency">
      <value value="17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-externalities">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="administrative-network-meetings">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-project-capacity">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-rounds-before-failed">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-municipal-network">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-year">
      <value value="2090"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-projects">
      <value value="true"/>
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
