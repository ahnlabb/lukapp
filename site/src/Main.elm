module Main exposing (main)

import Browser
import Dict
import Html exposing (Html, a, button, div, fieldset, footer, h1, h3, input, label, li, option, select, span, text, ul)
import Html.Attributes exposing (checked, class, href, placeholder, style, type_, value, width)
import Html.Events exposing (onClick, onInput)
import Markdown
import Page.CourseTable as CourseTable
import SiteData exposing (specializations)
import Svg
import Svg.Attributes


main : Program () Model Msg
main =
    Browser.element
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


init : () -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { page = Home }
    in
    ( model, Cmd.none )


type Msg
    = OpenCourseTable String
    | CourseTableMsg CourseTable.Msg
    | GoHome


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

        ( GoHome, CourseTable _ ) ->
            ( { model | page = Home }, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    updatePage model.page msg model


view : Model -> Html Msg
view { page } =
    div []
        [ Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "../style.css" ] []
        , case page of
            Home ->
                viewHome

            CourseTable subModel ->
                div []
                    [ div [ style "max-width" "150px" ] [ button [ onClick GoHome, class "landing-button" ] [ text "Home" ] ]
                    , CourseTable.view subModel
                        |> Html.map CourseTableMsg
                    ]
        ]


viewHome =
    div []
        [ Html.main_ [ class "wrapper" ]
            [ Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "../style.css" ] []
            , div [ class "row" ]
                [ colMd []
                    ([ button [ class "landing-button", onClick (OpenCourseTable "") ] [ text "All Courses" ] ]
                        ++ List.map (\( key, prog ) -> button [ class "landing-button", class "program-button", onClick (OpenCourseTable key) ] [ text prog.name ]) (Dict.toList specializations)
                    )
                , colMd [] [ about ]
                ]
            ]
        , foot
        ]


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


githubSvg : Html.Html msg
githubSvg =
    Svg.svg [ Svg.Attributes.height "16", Svg.Attributes.viewBox "0 0 16 16" ] [ Svg.path [ Svg.Attributes.fillRule "evenodd", Svg.Attributes.d "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z" ] [] ]


github : String -> Html.Html msg
github username =
    a [ href ("https://github.com/" ++ username) ] [ span [ class "icon--github" ] [ githubSvg ], span [ class "username" ] [ text username ] ]


type alias Developer =
    { name : String
    , title : String
    , username : String
    }


toHtml : Developer -> Html.Html msg
toHtml { name, title, username } =
    ul [ Html.Attributes.style "list-style-type" "none" ]
        [ li [] [ text name ]
        , li [ class "small-item" ] [ text title ]
        , li [ class "small-item" ] [ github username ]
        ]


foot : Html.Html msg
foot =
    footer []
        [ div [ class "footer-row" ]
            [ div [ class "footer-col" ] [ toHtml (Developer "Johannes Ahnlide" "Maintainer" "ahnlabb") ]
            ]
        , div [ class "footer-row" ]
            [ div [ class "footer-col" ] [ toHtml (Developer "Måns Magnusson" "Maintainer" "exoji2e") ]
            ]
        ]
