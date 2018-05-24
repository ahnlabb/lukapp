module Specializations exposing (specializations)

import Dict
import Json.Decode exposing (decodeString, dict, list, string)

specializations = Result.withDefault Dict.empty <| specData data

specData =
        decodeString <| dict <| dict <| list <| string

data =
