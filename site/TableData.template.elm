module TableData exposing (Course, courses)


type alias Course =
    { code : String
    , credits : Float
    , cycle : Int
    , name : String
    , pass : Int
    , score : Int
    , important : Int
    }


courses : List Course
courses =
