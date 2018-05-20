module Main exposing (..)

import Html exposing (Html, div, h1, input, text, select, option)
import Html.Attributes exposing (placeholder, value)
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

        acceptableCourses =
            List.filter (String.contains lowerQuery << String.toLower << Maybe.withDefault "-" << .code) courses
    in
        div []
            [ h1 [] [ text "Courses" ]
            , input [ placeholder "Filter by Course Code", onInput SetQuery ] []
            , Table.view config tableState acceptableCourses
            ]


config : Table.Config Course Msg
config =
    Table.config
        { toId = Maybe.withDefault "-" << .code
        , toMsg = SetTableState
        , columns =
            [ maybeStringColumn "Course Code" .code
            , maybeFloatColumn "Credits" .credits
            , maybeIntColumn "Cycle" .cycle
            , maybeStringColumn "Course Name" .name
            , maybeIntColumn "Pass Rate (%)" .pass
            , maybeIntColumn "CEQ overall score" .score
            , maybeIntColumn "CEQ importance for my education" .important
            ]
        }


cycles : List String
cycles =
    [ "G1", "G2", "A" ]


toEnum : List String -> Int -> Maybe String
toEnum lst num =
    List.head (List.drop num lst)


maybeIntColumn : String -> (data -> Maybe Int) -> Table.Column data msg
maybeIntColumn name toMaybeInt =
    Table.customColumn
        { name = name
        , viewData = Maybe.withDefault "-" << Maybe.map toString << toMaybeInt
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault -1000 << toMaybeInt)
        }


maybeFloatColumn : String -> (data -> Maybe Float) -> Table.Column data msg
maybeFloatColumn name toMaybeFloat =
    Table.customColumn
        { name = name
        , viewData = Maybe.withDefault "-" << Maybe.map toString << toMaybeFloat
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault -1.0 << toMaybeFloat)
        }


maybeStringColumn : String -> (data -> Maybe String) -> Table.Column data msg
maybeStringColumn name toMaybeString =
    Table.customColumn
        { name = name
        , viewData = Maybe.withDefault "-" << toMaybeString
        , sorter = Table.increasingOrDecreasingBy (Maybe.withDefault "" << toMaybeString)
        }
