module Main exposing (main)

import Markdown
import Page.CourseTable as CourseTable
import Html exposing (Html, div, h1, h3, input, text, select, option, a, fieldset, label, button, span)
import Html.Attributes exposing (placeholder, value, href, style, width, type_, checked, class)
import Html.Events exposing (onInput, onClick)
import SiteData exposing (specializations)
import Dict


main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


type Page
    = Home
    | CourseTable CourseTable.Model


type alias Model =
    { page : Page }


init : ( Model, Cmd Msg )
init =
    let
        model =
            { page = Home }
    in
        ( model, Cmd.none )


type Msg
    = OpenCourseTable String
    | CourseTableMsg CourseTable.Msg


updatePage : Page -> Msg -> Model -> ( Model, Cmd Msg )
updatePage page msg model =
    let
        toPage toModel toMsg subUpdate subMsg subModel =
            let
                ( newModel, newCmd ) =
                    subUpdate subMsg subModel
            in
                ( { model | page = toModel newModel }, Cmd.map toMsg newCmd )
    in
        case ( msg, page ) of
            ( OpenCourseTable prog, Home ) ->
                ( { model | page = CourseTable (CourseTable.initModel (Just prog)) }, Cmd.none )

            ( CourseTableMsg subMsg, CourseTable subModel ) ->
                toPage CourseTable CourseTableMsg CourseTable.update subMsg subModel

            ( _, _ ) ->
                ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    updatePage model.page msg model


view : Model -> Html Msg
view { page } =
    case page of
        Home ->
            div [ class "row" ]
                ([ Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "style.css" ] []
                 , colMd []
                    ([ button [ class "landing-button", onClick (OpenCourseTable "") ] [ text "All Courses" ] ]
                        ++ (List.map (\prog -> button [ class "landing-button", class "program-button", onClick (OpenCourseTable prog) ] [ text prog ]) (Dict.keys specializations))
                    )
                 , colMd [] [ about ]
                 ]
                )

        CourseTable subModel ->
            CourseTable.view subModel
                |> Html.map CourseTableMsg


colMd : List (Html.Attribute msg) -> List (Html.Html msg) -> Html.Html msg
colMd attr =
    div ([ class "col" ] ++ attr)


about : Html.Html msg
about =
    Markdown.toHtml [ class "about" ] """
## lukapp
- View all of LTH's courses
- Sort them by CEQ-score and pass rate
- Filter by course code or name

This tool will make it easier for students to pick courses,
create exposure for the CEQ-reports and encourage more students to fill out the forms.

The code is open source and lives at
[github](https://github.com/ahnlabb/lot-extract). Please add feature requests as
issues.
"""
