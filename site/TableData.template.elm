module TableData exposing (Course, courses)


type alias Course =
    { code : Maybe String
    , credits : Maybe Float
    , cycle : Maybe Int
    , name : Maybe String
    , webpage : Maybe String
    , ceqUrl : Maybe String
    , pass : Maybe Int
    , score : Maybe Int
    , important : Maybe Int
    , teaching : Maybe Int
    , goals : Maybe Int
    , assessment : Maybe Int
    , workload : Maybe Int
    }


courses : List Course
courses =
