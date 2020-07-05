module SiteData exposing (Course, coordinators, courses, specializations)

import Csv exposing (parse)
import Csv.Decode as CD exposing (andMap, decodeCsv, field, map, maybe)
import Dict
import Json.Decode as JD exposing (decodeString, dict, index, list, map2, map3, string)


type alias Specialization =
    { id : String
    , name : String
    , courselist : List String
    }


type alias Program =
    { name : String
    , specializations : List Specialization
    }


type alias Coordinator =
    { email : String
    , name : String
    }


type alias Course =
    { code : String
    , credits : Maybe Float
    , cycle : Maybe Int
    , name : Maybe String
    , webpage : Maybe String
    , ceqUrl : Maybe String
    , pass : Maybe Int
    , ceqAnswers : Maybe Int
    , score : Maybe Int
    , important : Maybe Int
    , teaching : Maybe Int
    , goals : Maybe Int
    , assessment : Maybe Int
    , workload : Maybe Int
    }


decodeSucceed result =
    case result of
        Ok list ->
            list

        _ ->
            []


parseMaybe parser str =
    case parser str of
        Just result ->
            Ok result

        Nothing ->
            Err str


parseFloat =
    parseMaybe String.toFloat


parseInt =
    parseMaybe String.toInt


decodeCourses =
    map Course
        (field "course_code" Ok
            |> andMap (field "credits" (maybe parseFloat))
            |> andMap (field "cycle" (maybe parseInt))
            |> andMap (field "course_name" (maybe Ok))
            |> andMap (field "links_W" (maybe Ok))
            |> andMap (field "ceq_url" (maybe Ok))
            |> andMap (field "ceq_pass_share" (maybe parseInt))
            |> andMap (field "ceq_answers" (maybe parseInt))
            |> andMap (field "ceq_overall_score" (maybe parseInt))
            |> andMap (field "ceq_important" (maybe parseInt))
            |> andMap (field "ceq_good_teaching" (maybe parseInt))
            |> andMap (field "ceq_clear_goals" (maybe parseInt))
            |> andMap (field "ceq_assessment" (maybe parseInt))
            |> andMap (field "ceq_workload" (maybe parseInt))
        )


courses =
    parse courseData
        |> decodeCsv decodeCourses
        |> decodeSucceed
        |> List.map (\course -> ( course.code, course ))
        |> Dict.fromList


specializations =
    Result.withDefault Dict.empty <| specDecode specData


specTupleDecoder =
    map3 Specialization (index 0 string) (index 1 string) (index 2 (list string))


specDecode =
    decodeString (dict (map2 Program (index 0 string) (index 1 (list specTupleDecoder))))


courseCoordinatorDecode =
    decodeString (dict (list (JD.map2 Coordinator (JD.field "email" string) (JD.field "name" string))))


coordinators =
    Result.withDefault Dict.empty <| courseCoordinatorDecode courseCoordinatorData


courseData : String
courseData =
    """$courses"""


specData =
    """
        $specializations
        """


courseCoordinatorData =
    """$course_coordinators"""
