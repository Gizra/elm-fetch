module Gizra.FetchSpec exposing (spec)

import Expect
import Gizra.Update exposing (..)
import List
import Test exposing (..)


type alias Model =
    List String


emptyModel : Model
emptyModel =
    []


type Msg
    = AddString String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AddString s ->
            ( s :: model, Cmd.none )


{-|

  - By adding "fetch-4" only if "fetch-3" is present, we're testing that we really recurse.

  - By adding multiple strings in the initial case, we're testing that we only recurse once
    the full list is processed. Otherwise, we'll end up with duplicate strings in our model.

-}
fetch : Model -> List Msg
fetch model =
    if List.member "fetch-4" model then
        []
    else if List.member "fetch-3" model then
        [ AddString "fetch-4" ]
    else
        [ AddString "fetch-1"
        , AddString "fetch-2"
        , AddString "fetch-3"
        ]


updateAndThenFetch : Msg -> Model -> ( Model, Cmd Msg )
updateAndThenFetch =
    andThenFetch fetch update


spec : Test
spec =
    describe "Update.Update"
        [ describe "andThenFetch"
            [ test "it recurses once full list processed, and eventually terminates" <|
                \_ ->
                    updateAndThenFetch (AddString "test") emptyModel
                        |> Tuple.first
                        |> Expect.equal [ "fetch-4", "fetch-3", "fetch-2", "fetch-1", "test" ]
            ]
        ]
