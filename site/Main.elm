module Main exposing (..)

import Html exposing (Html, div, h1, input, text, select, option, a)
import Html.Attributes exposing (placeholder, value, href, style, width)
import Html.Events exposing (onInput, onClick)
import Table
import TableData exposing (Course, courses)


main =
    Html.program
        { init = init courses
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    { courses : List Course
    , tableState : Table.State
    , query : String
    }


init : List Course -> ( Model, Cmd Msg )
init courses =
    let
        model =
            { courses = courses
            , tableState = Table.initialSort "Course Code"
            , query = ""
            }
    in
        ( model, Cmd.none )


type Msg
    = SetQuery String
    | SetTableState Table.State


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


view : Model -> Html Msg
view { courses, tableState, query } =
    let
        lowerQuery =
            String.toLower query

        containsQuery =
            String.contains lowerQuery << String.toLower << defaultEntry

        acceptableCourses =
            List.filter (\course -> containsQuery (.code course) || containsQuery (.name course)) courses
    in
        div []
            [ Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "style.css" ] []
            , h1 [] [ text "Courses" ]
            , input [ placeholder "Filter by Name or Code", onInput SetQuery ] []
            , Table.view config tableState acceptableCourses
            ]


defaultEntry : Maybe String -> String
defaultEntry =
    Maybe.withDefault "-"


switchMaybe ifJust ifNothing test =
    case test of
        Just _ ->
            ifJust

        Nothing ->
            ifNothing


ceqLink code ceqlink =
    case ceqlink of
        Just lnk ->
            lnk

        Nothing ->
            case code of
                Just c ->
                    "http://www.ceq.lth.se/rapporter/?kurskod=" ++ c ++ "&lang=en"

                Nothing ->
                    "http://www.ceq.lth.se/rapporter/?lang=en"


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
        { toId = Maybe.withDefault "-" << .code
        , toMsg = SetTableState
        , columns =
            [ maybeStringColumn "Course Code" .code
            , maybeFloatColumn "Credits" .credits
            , maybeStringColumn "Cycle" (Maybe.andThen (toEnum cycles) << .cycle)
            , maybeStringColumn "Course Name" .name
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


maybeIntColumn : String -> (data -> Maybe Int) -> Table.Column data msg
maybeIntColumn name toMaybeInt =
    Table.customColumn
        { name = name
        , viewData = defaultEntry << Maybe.map toString << toMaybeInt
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault -1000 << toMaybeInt)
        }


maybeFloatColumn : String -> (data -> Maybe Float) -> Table.Column data msg
maybeFloatColumn name toMaybeFloat =
    Table.customColumn
        { name = name
        , viewData = defaultEntry << Maybe.map toString << toMaybeFloat
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault -1.0 << toMaybeFloat)
        }


maybeStringColumn : String -> (data -> Maybe String) -> Table.Column data msg
maybeStringColumn name toMaybeString =
    Table.customColumn
        { name = name
        , viewData = defaultEntry << toMaybeString
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault "" << toMaybeString)
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
