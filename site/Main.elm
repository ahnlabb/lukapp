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
            List.filter (String.contains lowerQuery << String.toLower << .code) courses
    in
        div []
            [ h1 [] [ text "Courses" ]
            , input [ placeholder "Filter by Course Code", onInput SetQuery ] []
            , Table.view config tableState acceptableCourses
            ]


config : Table.Config Course Msg
config =
    Table.config
        { toId = .code
        , toMsg = SetTableState
        , columns =
            [ Table.stringColumn "Course Code" .code
            , Table.floatColumn "Credits" .credits
            , Table.stringColumn "Cycle" (toEnum cycles << .cycle)
            , Table.stringColumn "Course Name" .name
            , Table.intColumn "Pass Rate (%)" .pass
            , Table.intColumn "CEQ overall score" .score
            , Table.intColumn "CEQ importance for my education" .important
            ]
        }


cycles : List String
cycles =
    [ "G1", "G2", "A" ]


toEnum : List String -> Int -> String
toEnum lst num =
    Maybe.withDefault "" (List.head (List.drop num lst))
