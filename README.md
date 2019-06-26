[![Build Status](https://travis-ci.org/Gizra/elm-fetch.svg?branch=master)](https://travis-ci.org/Gizra/elm-fetch)

# elm-fetch

Some conveniences for implementing the `update` function with `fetch`.

The primary purpose of the `update` function is to take a `msg` and
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

Your `main` function would look something like:

```elm
main =
    Browser.element
        { init = App.Update.init

        -- We wire `andThenFetch` here.
        , update = Update.Fetch.andThenFetch App.Fetch.fetch App.Update.update
        , view = App.View.view
        , subscriptions = App.Update.subscriptions
        }
```

`App.Update.update` is your normal update function.
`App.Fetch.fetch` will likely look something like this, assuming you have a Page called `Items`:

```elm
{-| Call the needed `fetch` function, based on the active page.
-}
fetch : App.Model.Model -> List App.Model.Msg
fetch model =
    case model.activePage of
        Items ->
            Pages.Items.Fetch.fetch model.backend
                |> List.map (\subMsg -> MsgBackend subMsg)
```

# Maintainers

* [@rgrempel](https://github.com/rgrempel)
* [@amitaibu](https://github.com/amitaibu)

