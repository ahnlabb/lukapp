module SiteData exposing (Course, courses, specializations)

import Dict
import Json.Decode exposing (decodeString, dict, list, string, map3, map2, index)
import Csv.Decode exposing (andMap, field, map, maybe, decodeCsv)
import Csv exposing (parse)


type alias Specialization =
    { id : String
    , name : String
    , courselist : List String
    }


type alias Program =
    { name : String
    , specializations : List Specialization
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


decodeCourses =
    map Course
        (field "course_code" Ok
            |> andMap (field "credits" (maybe String.toFloat))
            |> andMap (field "cycle" (maybe String.toInt))
            |> andMap (field "course_name" (maybe Ok))
            |> andMap (field "links_W" (maybe Ok))
            |> andMap (field "ceq_url" (maybe Ok))
            |> andMap (field "ceq_pass_share" (maybe String.toInt))
            |> andMap (field "ceq_answers" (maybe String.toInt))
            |> andMap (field "ceq_overall_score" (maybe String.toInt))
            |> andMap (field "ceq_important" (maybe String.toInt))
            |> andMap (field "ceq_good_teaching" (maybe String.toInt))
            |> andMap (field "ceq_clear_goals" (maybe String.toInt))
            |> andMap (field "ceq_assessment" (maybe String.toInt))
            |> andMap (field "ceq_workload" (maybe String.toInt))
        )


courses =
    parse courseData
        |> decodeCsv decodeCourses
        |> decodeSucceed
        |> List.map (\course -> ( course.code, course ))
        |> Dict.fromList


courseData : String
courseData =
    """$courses"""


specializations =
    Result.withDefault Dict.empty <| specDecode specData


specTupleDecoder =
    map3 Specialization (index 0 string) (index 1 string) (index 2 (list string))


specDecode =
    decodeString (dict (map2 Program (index 0 string) (index 1 (list specTupleDecoder))))


specData =
    """
        $specializations
        """
