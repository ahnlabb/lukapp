module TableData exposing (Course, courses)


type alias Course =
    { code : Maybe String
    , credits : Maybe Float
    , cycle : Maybe Int
    , name : Maybe String
    , pass : Maybe Int
    , score : Maybe Int
    , important : Maybe Int
    }


courses : List Course
courses =
