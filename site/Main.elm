module Main exposing (..)

import Html exposing (Html, div, h1, h3, input, text, select, option, a, fieldset, label)
import Html.Attributes exposing (placeholder, value, href, style, width, type_, checked, class)
import Html.Events exposing (onInput, onClick)
import Dict
import Table
import SiteData exposing (specializations, Course, courses)


main =
    Html.program
        { init = init courses
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    { courses : Dict.Dict String Course
    , tableState : Table.State
    , ceqOnly : Bool
    , query : String
    , program : Maybe String
    }


init : Dict.Dict String Course -> ( Model, Cmd Msg )
init courses =
    let
        model =
            { courses = courses
            , tableState = Table.initialSort "Course Code"
            , ceqOnly = False
            , query = ""
            , program = Nothing
            }
    in
        ( model, Cmd.none )


type Msg
    = SetQuery String
    | SetTableState Table.State
    | ToggleCeqOnly
    | SetProgram String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetQuery newQuery ->
            ( { model | query = newQuery }
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


view : Model -> Html Msg
view { courses, tableState, ceqOnly, query, program } =
    let
        lowerQuery =
            String.toLower query

        containsQuery =
            String.contains lowerQuery << String.toLower

        queriedFilter =
            List.filter (\course -> containsQuery (.code course) || containsQuery (defaultEntry (.name course)))

        hasCeqFilter =
            List.filter <| ((<) 3) << (Maybe.withDefault 0) << .ceqAnswers

        courseLists prog =
            Maybe.andThen (\p -> Dict.get p specializations) prog
                |> Maybe.map (List.map (\spec -> ( spec.name, spec.courselist )))
                |> Maybe.withDefault ([ ( "All Courses", Dict.keys courses ) ])

        courseFilter list =
            (if ceqOnly then
                (hasCeqFilter << queriedFilter)
             else
                queriedFilter
            )
                (List.filterMap (\k -> Dict.get k courses) list)

        tableFromList list =
            div []
                [ h3 [] [ text (Tuple.first list) ]
                , Table.view config tableState (Tuple.second list)
                ]
    in
        div []
            ([ Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "style.css" ] []
             , h1 [] [ text "Courses" ]
             , fieldset []
                [ input [ placeholder "Filter by Name or Code", onInput SetQuery ] []
                , label []
                    [ text "Program: "
                    , select [ onInput SetProgram ] <| List.concat [ [ option [ value "" ] [ text "all" ] ], List.map (\prog -> option [ value prog ] [ text prog ]) (Dict.keys specializations) ]
                    ]
                , label []
                    [ input [ type_ "checkbox", onClick ToggleCeqOnly, checked ceqOnly ] []
                    , text "Only show courses with at least 3 CEQ answers"
                    ]
                ]
             ]
                ++ (List.map tableFromList (List.map (Tuple.mapSecond courseFilter) (courseLists program)))
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
    Html.span [ style [ ( "color", color ) ] ] [ Html.text (" " ++ symbol) ]


config : Table.Config Course Msg
config =
    Table.customConfig
        { toId = .code
        , toMsg = SetTableState
        , columns =
            [ Table.stringColumn "Course Code" .code
            , maybeFloatColumn "Credits" .credits
            , maybeStringColumn "Cycle" (Maybe.andThen (toEnum cycles) << .cycle)
            , longStringColumn "Course Name" .name
            , maybeLinkColumn "Webpage" (\data -> Maybe.map (SimpleLink "link") (.webpage data))
            , linkColumn "CEQ" (\data -> SimpleLink "link" (ceqLink (.code data) (.ceqUrl data)))
            , maybeIntColumn "Pass Rate (%)" .pass
            , maybeIntColumn "Score" .score
            , maybeIntColumn "Importance" .important
            , maybeIntColumn "Teaching" .teaching
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
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault valueDefault << toMaybe)
        }


maybeColumn : comparable -> String -> (data -> Maybe comparable) -> Table.Column data msg
maybeColumn =
    customMaybeColumn ((Maybe.withDefault "-") << (Maybe.map toString))


maybeIntColumn : String -> (data -> Maybe Int) -> Table.Column data msg
maybeIntColumn =
    maybeColumn -101


maybeFloatColumn : String -> (data -> Maybe Float) -> Table.Column data msg
maybeFloatColumn =
    maybeColumn -1.0


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
