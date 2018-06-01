module Main exposing (main)

import Markdown
import Page.CourseTable as CourseTable
import Html exposing (Html, div, h1, h3, input, text, select, option, a, fieldset, label, button, span)
import Html.Attributes exposing (placeholder, value, href, style, width, type_, checked, class)
import Html.Events exposing (onInput, onClick)


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
            div []
                ([ Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "style.css" ] []
                 , about
                 ]
                    ++ (List.map (\prog -> button [ onClick (OpenCourseTable prog) ] [ text prog ]) [ "A", "D", "F" ])
                )

        CourseTable subModel ->
            CourseTable.view subModel
                |> Html.map CourseTableMsg


about : Html.Html msg
about =
    Markdown.toHtml [ class "about" ] """
Frustrated with the slow webpage that displays course information in LTH's
programmes and the inaccesibility of CEQ-reports, we decided to make a tool
ourselves. With this tool you can view all of LTH's courses. Sort them by
ceq-score and pass rate, and filter by course code or name. We hope this tool
will make it easier for students to pick courses, expand the exposure of the
ceq-reports and encourage more students to fill in the forms.

The code is open source and lives at
[github](https://github.com/ahnlabb/lot-extract). Please add feature requests as
issues.
"""
