module Page.CourseTable exposing (Model, Msg, initModel, update, view)

import Dict
import Html exposing (Html, a, button, div, fieldset, h1, h3, input, label, option, select, span, text)
import Html.Attributes exposing (checked, class, href, placeholder, selected, style, type_, value, width)
import Html.Events exposing (onClick, onInput)
import Set
import SiteData exposing (Course, coordinators, courses, specializations)
import Table


type alias Model =
    { courses : Dict.Dict String Course
    , tableState : Table.State
    , collapsedTables : Set.Set String
    , ceqOnly : Bool
    , ceqExtended : Bool
    , query : String
    , coordinatorQuery : String
    , program : Maybe String
    }


initModel : Maybe String -> Model
initModel program =
    let
        model =
            { courses = courses
            , tableState = Table.initialSort "Course Code"
            , collapsedTables = Set.empty
            , ceqOnly = False
            , ceqExtended = False
            , query = ""
            , coordinatorQuery = ""
            , program = program
            }
    in
    model


type Msg
    = SetQuery String
    | SetCoordinatorQuery String
    | SetTableState Table.State
    | ToggleCollapse String
    | ToggleCeqOnly
    | ToggleCeqExtended
    | SetProgram String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetQuery newQuery ->
            ( { model | query = newQuery }
            , Cmd.none
            )

        SetCoordinatorQuery newQuery ->
            ( { model | coordinatorQuery = newQuery }
            , Cmd.none
            )

        SetTableState newState ->
            ( { model | tableState = newState }
            , Cmd.none
            )

        ToggleCeqOnly ->
            ( { model | ceqOnly = not model.ceqOnly }
            , Cmd.none
            )

        ToggleCeqExtended ->
            ( { model | ceqExtended = not model.ceqExtended }
            , Cmd.none
            )

        SetProgram newProgram ->
            ( { model
                | program =
                    if newProgram == "" then
                        Nothing

                    else
                        Just newProgram
              }
            , Cmd.none
            )

        ToggleCollapse tableTitle ->
            ( { model
                | collapsedTables =
                    if Set.member tableTitle model.collapsedTables then
                        Set.remove tableTitle model.collapsedTables

                    else
                        Set.insert tableTitle model.collapsedTables
              }
            , Cmd.none
            )


view : Model -> Html Msg
view { courses, tableState, collapsedTables, ceqOnly, ceqExtended, query, coordinatorQuery, program } =
    let
        insensitiveContains a b =
            String.contains (String.toLower a) (String.toLower b)

        containsQuery =
            insensitiveContains query

        queriedFilter course =
            containsQuery (.code course) || containsQuery (defaultEntry (.name course))

        hasCeqFilter =
            (<) 3 << Maybe.withDefault 0 << .ceqAnswers

        coordinatorFilter course =
            List.any (insensitiveContains coordinatorQuery) (getCoordinatorList course)

        courseLists prog =
            Maybe.andThen (\p -> Maybe.map .specializations (Dict.get p specializations)) prog
                |> Maybe.map (List.map (\spec -> ( spec.name, spec.courselist )))
                |> Maybe.withDefault [ ( "All Courses", Dict.keys courses ) ]

        prependIf pred el list =
            if pred then
                el :: list

            else
                list

        courseFilter list =
            List.filter
                (\course ->
                    List.all
                        ((|>) course)
                        ([ queriedFilter, coordinatorFilter ]
                            |> prependIf ceqOnly hasCeqFilter
                        )
                )
                (List.filterMap (\k -> Dict.get k courses) list)

        tableFromList titledList =
            let
                title =
                    Tuple.first titledList

                list =
                    Tuple.second titledList

                collapsed =
                    Set.member title collapsedTables

                symbol =
                    if collapsed then
                        "+ "

                    else
                        "- "
            in
            div []
                ([ button [ onClick (ToggleCollapse title), class "accordion" ]
                    [ span [ style "font-family" "\"Lucida Console\", Monaco, monospace" ] [ text symbol ]
                    , text title
                    ]
                 ]
                    ++ (if collapsed then
                            []

                        else
                            [ Table.view config tableState list ]
                       )
                )

        programOptionList =
            case program of
                Nothing ->
                    [ option [ value "" ] [ text "all" ] ] ++ List.map (\prog -> option [ value prog ] [ text prog ]) (Dict.keys specializations)

                Just p ->
                    [ option [ value "" ] [ text "all" ] ] ++ List.map (\prog -> option [ value prog, selected (prog == p) ] [ text prog ]) (Dict.keys specializations)
    in
    div []
        ([ Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "style.css" ] []
         , h1 []
            [ text "Courses for "
            , select [ style "display" "inline-block", style "background-color" "#fff", style "border-radius" "5px", style "color" "#444", style "font-size" "38px", onInput SetProgram ] programOptionList
            ]
         , fieldset []
            [ input [ placeholder "Filter by Name or Code", onInput SetQuery ] []
            , input [ placeholder "Filter by Coordinator/Teacher", onInput SetCoordinatorQuery ] []
            , div [] []
            , label []
                [ input [ type_ "checkbox", onClick ToggleCeqOnly, checked ceqOnly ] []
                , text "Only show courses with at least 3 CEQ answers"
                ]
            , div [] []
            , label []
                [ input [ type_ "checkbox", onClick ToggleCeqExtended, checked ceqExtended ] []
                , text "Show all CEQ parameters"
                ]
            ]
         ]
            ++ List.map tableFromList (List.map (Tuple.mapSecond courseFilter) (courseLists program))
        )


defaultEntry : Maybe String -> String
defaultEntry =
    Maybe.withDefault "-"


switchMaybe : a -> a -> Maybe b -> a
switchMaybe ifJust ifNothing test =
    case test of
        Just _ ->
            ifJust

        Nothing ->
            ifNothing


ceqLink : String -> Maybe String -> String
ceqLink code ceqlink =
    case ceqlink of
        Just lnk ->
            lnk

        Nothing ->
            "http://www.ceq.lth.se/rapporter/?kurskod=" ++ code ++ "&lang=en"


defaultCustomizations =
    Table.defaultCustomizations


customThead : List ( String, Table.Status, Html.Attribute msg ) -> Table.HtmlDetails msg
customThead headers =
    Table.HtmlDetails [] (List.map customTheadHelp headers)


customTheadHelp : ( String, Table.Status, Html.Attribute msg ) -> Html msg
customTheadHelp ( name, status, onClick ) =
    let
        content =
            case status of
                Table.Unsortable ->
                    [ Html.text name ]

                Table.Sortable selected ->
                    [ Html.text name
                    , if selected then
                        coloredSymbol "#555" "↓"

                      else
                        coloredSymbol "#ccc" "↓"
                    ]

                Table.Reversible Nothing ->
                    [ Html.text name
                    , coloredSymbol "#ccc" "↕"
                    ]

                Table.Reversible (Just isReversed) ->
                    [ Html.text name
                    , coloredSymbol "#555"
                        (if isReversed then
                            "↑"

                         else
                            "↓"
                        )
                    ]
    in
    Html.th [ onClick ] content


coloredSymbol color symbol =
    Html.span [ style "color" color ] [ Html.text (" " ++ symbol) ]


tableColumns =
    [ Table.stringColumn "Course Code" .code
    , maybeFloatColumn "Credits" .credits
    , maybeStringColumn "Cycle" (Maybe.andThen (toEnum cycles) << .cycle)
    , longStringColumn "Course Name" .name
    , maybeLinkColumn "Webpage" (\data -> Maybe.map (SimpleLink "link") (.webpage data))
    , linkColumn "CEQ" (\data -> SimpleLink "link" (ceqLink (.code data) (.ceqUrl data)))
    , maybeIntColumn "Pass Rate" .pass
    , maybeIntColumn "Score" .score
    , maybeIntColumn "Importance" .important
    , teacherColumn
    ]


getCoordinator course =
    getCoordinatorList course |> List.head


getCoordinatorList course =
    Dict.get course.code coordinators |> Maybe.withDefault [] |> List.map .name


config : Table.Config Course Msg
config =
    Table.customConfig
        { toId = .code
        , toMsg = SetTableState
        , columns = tableColumns
        , customizations = defaultCustomizations
        }


configCeqExtended : Table.Config Course Msg
configCeqExtended =
    Table.customConfig
        { toId = .code
        , toMsg = SetTableState
        , columns =
            tableColumns
                ++ [ maybeIntColumn "Teaching" .teaching
                   , maybeIntColumn "Goals" .goals
                   , maybeIntColumn "Assessment" .assessment
                   , maybeIntColumn "Workload" .workload
                   ]
        , customizations = defaultCustomizations
        }


cycles : List String
cycles =
    [ "G1", "G2", "A" ]


toEnum : List String -> Int -> Maybe String
toEnum lst num =
    List.head <| List.drop (num - 1) lst


customMaybeColumn : (Maybe comparable -> String) -> comparable -> String -> (data -> Maybe comparable) -> Table.Column data msg
customMaybeColumn toStr valueDefault name toMaybe =
    Table.customColumn
        { name = name
        , viewData = toStr << toMaybe
        , sorter = Table.decreasingOrIncreasingBy (Maybe.withDefault valueDefault << toMaybe)
        }


maybeColumn : (comparable -> String) -> comparable -> String -> (data -> Maybe comparable) -> Table.Column data msg
maybeColumn toString =
    customMaybeColumn (Maybe.withDefault "-" << Maybe.map toString)


maybeIntColumn : String -> (data -> Maybe Int) -> Table.Column data msg
maybeIntColumn =
    maybeColumn String.fromInt -101


maybeFloatColumn : String -> (data -> Maybe Float) -> Table.Column data msg
maybeFloatColumn =
    maybeColumn String.fromFloat -1.0


maybeStringColumn : String -> (data -> Maybe String) -> Table.Column data msg
maybeStringColumn =
    customMaybeColumn (Maybe.withDefault "-") ""


longStringColumn : String -> (data -> Maybe String) -> Table.Column data msg
longStringColumn name toStr =
    Table.veryCustomColumn
        { name = name
        , viewData = \data -> Table.HtmlDetails [ class "long" ] [ text ((Maybe.withDefault "" << toStr) data) ]
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault "" << toStr)
        }


type alias SimpleLink =
    { title : String
    , target : String
    }


viewLink : SimpleLink -> Table.HtmlDetails msg
viewLink { title, target } =
    Table.HtmlDetails []
        [ a [ href target ] [ text title ] ]


linkColumn : String -> (data -> SimpleLink) -> Table.Column data msg
linkColumn name toLink =
    Table.veryCustomColumn
        { name = name
        , viewData = viewLink << toLink
        , sorter = Table.increasingOrDecreasingBy (.title << toLink)
        }


viewMaybeLink : Maybe SimpleLink -> Table.HtmlDetails msg
viewMaybeLink maybeLink =
    case maybeLink of
        Just x ->
            viewLink x

        Nothing ->
            Table.HtmlDetails [] [ text "-" ]


maybeLinkColumn : String -> (data -> Maybe SimpleLink) -> Table.Column data msg
maybeLinkColumn name toMaybeLink =
    Table.veryCustomColumn
        { name = name
        , viewData = viewMaybeLink << toMaybeLink
        , sorter = Table.unsortable
        }


teacherColumn =
    let
        viewTeachers course =
            Table.HtmlDetails [] (List.map (\x -> div [] [ text x ]) (getCoordinatorList course))
    in
    Table.veryCustomColumn
        { name = "Teachers"
        , viewData = viewTeachers
        , sorter = Table.unsortable
        }
