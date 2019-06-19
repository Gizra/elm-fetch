module Update.Fetch exposing (andThenFetch, sequenceExtra)

{-| Some conveniences for implementing the `update` function.

Using the various functions in
[ccapndave/elm-update-extra](http://package.elm-lang.org/packages/ccapndave/elm-update-extra/latest)
is also highly recommended.

@docs andThenFetch, sequenceExtra

-}

import List
import Update.Extra exposing (sequence)


{-| Like `Update.Extra.sequence`, but for `update` signatures that also
return a list of extra messages for the caller to handle.

Essentially, this allows you to recursively apply a whole sequence of messages,
collecting their results. So, with `Update.Extra.sequence` you can do something
like this:

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            SomeMsg ->
                sequence update
                    [ AnotherMsg, YetAnotherMsg, AThirdMsg ]
                    ( model, Cmd.none )

Isn't that nice? Essentially, you get a really expressive way of constructing
a "composite" message. Plus, you can do something first ... that is, you could
modify the model, and have your own `Cmd`, and then feed that into the `sequence`
for further processing.

So, what is `sequenceExtra`? It deals with an alternative `update` signature,
in which we're returning a third element to our tuple, with extra messages that
the caller is expected to handle. So, you can follow the same idiom as shown above.

    update : Msg -> Model -> ( Model, Cmd Msg, List extraMsg )
    update msg model =
        case msg of
            SomeMsg ->
                sequenceExtra update
                    [ AnotherMsg, YetAnotherMsg, AThirdMsg ]
                    ( model, Cmd.none, [] )

-}
sequenceExtra :
    (msg -> model -> ( model, Cmd msg, List extraMsg ))
    -> List msg
    -> ( model, Cmd msg, List extraMsg )
    -> ( model, Cmd msg, List extraMsg )
sequenceExtra updater msgs startingPoint =
    List.foldl
        (\eachMsg ( modelSoFar, cmdsSoFar, msgsSoFar ) ->
            let
                ( newModel, newCmd, newMsgs ) =
                    updater eachMsg modelSoFar
            in
            ( newModel
            , Cmd.batch [ cmdsSoFar, newCmd ]
            , msgsSoFar ++ newMsgs
            )
        )
        startingPoint
        msgs


{-| The primary purpose of the `update` function is to take a `msg` and
return an updated `model` (and possibly a `Cmd`). So, what one ordinarily does
in an `update` function is run a `case` statement on the `msg`, doing whatever
is appropriate for the provided `msg`.

However, there are times when we want to take certain actions based not on the
`msg` we just received, but instead on the state of our `model` generally ...
particularly the state of whatever is controlling our `view`. For instance, we
may need to load some data from the backend in order to support the current
view. That will require a `Cmd`, but it is logically independent of the
current `msg`. Well, I suppose you could try to "catch" every message that
creates a requirement to fetch some data, but that is error prone -- it would
be nicer to just compute what messages are necessary, given the state of the
model.

So, imagine that you have a function like this:

    fetch : Model -> List Msg

Its job is to look at the model and decide whether there are any messages that
ought to be processed (e.g. to fetch some needed data, but it isn't really
limited to that). It's convenient for this to be a separate function (that is,
separate from `update`), because it doesn't depend on the `msg` ... it will be
a function of something in the model which indicates what the `view` needs.

However, we also need to apply this `fetch` function. That is where `andThenFetch`
comes in. You provide:

  - your `fetch` function
  - your `update` function

What you get back is a function that has the same signature as your `update`
function ... that is, it is also in the form `Msg -> Model -> (Model, Cmd
Msg)`. However, after it calls your own `update` function, it calls your
`fetch` function with the resulting `Model`, and then feeds those results back
into your `update` function. So, whatever messages your `fetch` function
returns will be processed.

Note that this will run recursively ... that is, when your `fetch` function
returns some messages to process, it will be called again with the results of
processing those messages. So, you will need something in your model to
keep track of actions in progress (e.g. `RemoteData`) so that you don't
repeatedly kick off the same action in an infinite loop.

To use this function, you would normally just supply the first two parameters
... that is, your `fetch` function and your normal `update` function. What you
will then get back is a function of the form `msg -> model -> ( model, Cmd msg)` ...
that is, an `update` function that you can then pass to `programWithFlags` (or
use in another way).

-}
andThenFetch : (model -> List msg) -> (msg -> model -> ( model, Cmd msg )) -> msg -> model -> ( model, Cmd msg )
andThenFetch fetch update msg model =
    -- First, we do the "regular" update, then we apply the `fetch` logic.  In
    -- principle, we could integrate with `animationFrame` in some way.  Since
    -- this is driven by the needs of the view, there's no need to check any
    -- faster than the view is drawn.
    update msg model
        |> applyFetch fetch update


applyFetch : (model -> List msg) -> (msg -> model -> ( model, Cmd msg )) -> ( model, Cmd msg ) -> ( model, Cmd msg )
applyFetch fetch update resultSoFar =
    -- Note that we call ourselves recursively. So, it's vitally important that
    -- the `fetch` implementations use a `WebData`-like strategy to indicate
    -- that a request is in progress, and doesn't need to be triggered again.
    -- Otherwise, we'll immediately be in an infinite loop.
    --
    -- We initially sequence through the app's `update`, and only recurse once
    -- all the messages have been processed.
    let
        msgs =
            fetch (Tuple.first resultSoFar)
    in
    if List.isEmpty msgs then
        resultSoFar

    else
        sequence update msgs resultSoFar
            |> applyFetch fetch update
