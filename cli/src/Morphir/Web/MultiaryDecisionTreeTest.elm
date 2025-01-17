module Morphir.Web.MultiaryDecisionTreeTest exposing (..)

import Browser
import Dict exposing (Dict, values)
import Html exposing (Html, button, label, map, option, select)
import Html.Attributes as Html exposing (class, disabled, for, id, selected, value)
import Html.Events exposing (onClick, onInput)
import Maybe exposing (withDefault)
import Morphir.IR.Literal exposing (Literal(..))
import Morphir.IR.Name as Name exposing (Name)
import Morphir.IR.Value as Value exposing (Pattern(..), RawValue, Value(..))
import Morphir.Value.Interpreter as Interpreter
import Morphir.Visual.ViewPattern as ViewPattern
import String exposing (fromInt, join, split)
import Tree as Tree
import TreeView as TreeView
import Tuple



-- Data type to represent condition and pattern of each node.


type alias NodeData =
    { uid : String
    , subject : String
    , pattern : Maybe (Pattern ())
    , highlight : Bool
    }



-- Styling visual representation of a Pattern


getLabel : Maybe (Pattern ()) -> String
getLabel maybeLabel =
    case maybeLabel of
        Just label ->
            ViewPattern.patternAsText label ++ " - "

        Nothing ->
            ""



-- Evaluates node and pattern based on whether or not it is within variables which is passed from the dropdowns


evaluateHighlight : Dict Name (Value () ()) -> String -> Pattern () -> Bool
evaluateHighlight variables value pattern =
    let
        evaluation : Maybe.Maybe RawValue
        evaluation =
            variables |> Dict.get (Name.fromString value)
    in
    case evaluation of
        Just val ->
            case Interpreter.matchPattern pattern val of
                Ok _ ->
                    True

                Err _ ->
                    False

        Nothing ->
            False



-- creates label from nodedata


nodeLabel : Tree.Node NodeData -> String
nodeLabel n =
    case n of
        Tree.Node node ->
            getLabel node.data.pattern ++ node.data.subject



-- takes in an IR, calls a function to get a decision tree which is represented by a root node,
-- and returns an initial model


initialModel : () -> ( Model, Cmd Msg )
initialModel () =
    let
        originalIR =
            Value.patternMatch ()
                (Value.Variable () [ "Classify By Position Type" ])
                [ ( Value.LiteralPattern () (StringLiteral "Cash")
                  , Value.IfThenElse ()
                        (Value.Variable () [ "Is Central Bank" ])
                        (Value.IfThenElse ()
                            (Value.Variable () [ "Is Segregated Cash" ])
                            (Value.PatternMatch ()
                                (Value.Variable () [ "Classify By Counter Party ID" ])
                                [ ( Value.LiteralPattern () (StringLiteral "FRD"), Value.Variable () [ "I.A.4.1" ] )
                                , ( Value.LiteralPattern () (StringLiteral "BOE"), Value.Variable () [ "I.A.4.2" ] )
                                , ( Value.LiteralPattern () (StringLiteral "SNB"), Value.Variable () [ "I.A.4.3" ] )
                                , ( Value.LiteralPattern () (StringLiteral "ECB"), Value.Variable () [ "I.A.4.4" ] )
                                , ( Value.LiteralPattern () (StringLiteral "BOJ"), Value.Variable () [ "I.A.4.5" ] )
                                , ( Value.LiteralPattern () (StringLiteral "RBA"), Value.Variable () [ "I.A.4.6" ] )
                                , ( Value.LiteralPattern () (StringLiteral "BOC"), Value.Variable () [ "I.A.4.7" ] )
                                , ( Value.LiteralPattern () (StringLiteral "Others"), Value.Variable () [ "I.A.4.8" ] )
                                ]
                            )
                            (Value.PatternMatch ()
                                (Value.Variable () [ "Classify By Counter Party ID" ])
                                [ ( Value.LiteralPattern () (StringLiteral "FRD"), Value.Variable () [ "I.A.3.1" ] )
                                , ( Value.LiteralPattern () (StringLiteral "BOE"), Value.Variable () [ "I.A.3.2" ] )
                                , ( Value.LiteralPattern () (StringLiteral "SNB"), Value.Variable () [ "I.A.3.3" ] )
                                , ( Value.LiteralPattern () (StringLiteral "ECB"), Value.Variable () [ "I.A.3.4" ] )
                                , ( Value.LiteralPattern () (StringLiteral "BOJ"), Value.Variable () [ "I.A.3.5" ] )
                                , ( Value.LiteralPattern () (StringLiteral "RBA"), Value.Variable () [ "I.A.3.6" ] )
                                , ( Value.LiteralPattern () (StringLiteral "BOC"), Value.Variable () [ "I.A.3.7" ] )
                                , ( Value.LiteralPattern () (StringLiteral "Others"), Value.Variable () [ "I.A.3.8" ] )
                                ]
                            )
                        )
                        (Value.IfThenElse ()
                            (Value.Variable () [ "Is On Shore" ])
                            (Value.IfThenElse ()
                                (Value.Variable () [ "Is NetUsd Amount Negative" ])
                                (Value.Variable () [ "O.W.9" ])
                                (Value.IfThenElse ()
                                    (Value.Variable () [ "Is Feed44 and CostCenter Not 5C55" ])
                                    (Value.Variable () [ "I.U.1" ])
                                    (Value.Variable () [ "I.U.4" ])
                                )
                            )
                            (Value.IfThenElse ()
                                (Value.Variable () [ "Is NetUsd Amount Negative" ])
                                (Value.Variable () [ "O.W.10" ])
                                --
                                (Value.IfThenElse ()
                                    (Value.Variable () [ "Is Feed44 and CostCenter Not 5C55" ])
                                    (Value.Variable () [ "I.U.2" ])
                                    (Value.Variable () [ "I.U.4" ])
                                )
                             --
                            )
                        )
                  )
                , ( Value.LiteralPattern () (StringLiteral "Inventory"), Value.Unit () )
                , ( Value.LiteralPattern () (StringLiteral "Pending Trades"), Value.Unit () )
                ]
    in
    ( { rootNodes = listToNode [ originalIR ] Dict.empty
      , dict = Dict.empty
      , treeModel = TreeView.initializeModel2 configuration (listToNode [ originalIR ] Dict.empty)
      , selectedNode = Nothing
      , originalIR = originalIR
      }
    , Cmd.none
    )



-- holds a dictionary and the original IR to enable realtime highlighting


type alias Model =
    { rootNodes : List (Tree.Node NodeData)
    , treeModel : TreeView.Model NodeData String NodeDataMsg (Maybe NodeData)
    , selectedNode : Maybe NodeData
    , dict : Dict String String
    , originalIR : Value () ()
    }


nodeUidOf : Tree.Node NodeData -> TreeView.NodeUid String
nodeUidOf n =
    case n of
        Tree.Node node ->
            TreeView.NodeUid node.data.uid


configuration : TreeView.Configuration2 NodeData String NodeDataMsg (Maybe NodeData)
configuration =
    TreeView.Configuration2 nodeUidOf viewNodeData TreeView.defaultCssClasses


type Msg
    = TreeViewMsg (TreeView.Msg2 String NodeDataMsg)
    | SetDictValueRoot String
    | SetDictValueBank String
    | SetDictValueSegCash String
    | SetDictValueCode String
    | SetDictValueShore String
    | SetDictValueNegative String
    | SetDictValueFeed String



-- updates based on drop downs, collapsible and expandable buttons, and selections


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        SetDictValueRoot s1 ->
            let
                newDict1 =
                    Dict.insert "classifyByPositionType" s1 model.dict
            in
            ( { model
                | dict = newDict1
                , treeModel = TreeView.initializeModel2 configuration (listToNode [ model.originalIR ] newDict1)
              }
            , Cmd.none
            )

        SetDictValueBank s1 ->
            let
                newDict1 =
                    Dict.insert "isCentralBank" s1 model.dict
            in
            ( { model
                | dict = newDict1
                , treeModel = TreeView.initializeModel2 configuration (listToNode [ model.originalIR ] newDict1)
              }
            , Cmd.none
            )

        SetDictValueSegCash s1 ->
            let
                newDict1 =
                    Dict.insert "isSegregatedCash" s1 model.dict
            in
            ( { model
                | dict = newDict1
                , treeModel = TreeView.initializeModel2 configuration (listToNode [ model.originalIR ] newDict1)
              }
            , Cmd.none
            )

        SetDictValueCode s1 ->
            let
                newDict1 =
                    Dict.insert "classifyByCounterPartyID" s1 model.dict
            in
            ( { model
                | dict = newDict1
                , treeModel = TreeView.initializeModel2 configuration (listToNode [ model.originalIR ] newDict1)
              }
            , Cmd.none
            )

        SetDictValueShore s1 ->
            let
                newDict1 =
                    Dict.insert "isOnShore" s1 model.dict
            in
            ( { model
                | dict = newDict1
                , treeModel = TreeView.initializeModel2 configuration (listToNode [ model.originalIR ] newDict1)
              }
            , Cmd.none
            )

        SetDictValueNegative s1 ->
            let
                newDict1 =
                    Dict.insert "isNetUsdAmountNegative" s1 model.dict
            in
            ( { model
                | dict = newDict1
                , treeModel = TreeView.initializeModel2 configuration (listToNode [ model.originalIR ] newDict1)
              }
            , Cmd.none
            )

        SetDictValueFeed s1 ->
            let
                newDict1 =
                    Dict.insert "isFeed44andCostCenterNot5C55" s1 model.dict
            in
            ( { model | dict = newDict1, treeModel = TreeView.initializeModel2 configuration (listToNode [ model.originalIR ] newDict1) }, Cmd.none )

        _ ->
            let
                treeModel =
                    case message of
                        TreeViewMsg tvMsg ->
                            TreeView.update2 tvMsg model.treeModel

                        _ ->
                            model.treeModel

                selectedNode =
                    TreeView.getSelected treeModel |> Maybe.map .node |> Maybe.map Tree.dataOf
            in
            ( { model
                | treeModel = treeModel
                , selectedNode = selectedNode
              }
            , Cmd.none
            )


view : Model -> Html.Html Msg
view model =
    Html.div
        [ class "center-screen" ]
        [ dropdowns model
        , map TreeViewMsg (TreeView.view2 model.selectedNode model.treeModel)
        ]


main =
    Browser.element
        { init = initialModel
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- hard coded dropdowns


dropdowns : Model -> Html.Html Msg
dropdowns model =
    Html.div []
        [ Html.div [ id "all-dropdowns", Html.style "color" "white" ]
            [ label [ class "title-arboretum" ] [ Html.text "Arboretum" ]
            , label [ id "cash-select-label", for "cash-select" ] [ Html.text "Choose a Product: " ]
            , select [ id "cash-select", onInput SetDictValueRoot, class "dropdown" ]
                [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                , option [ value "Is Central Bank/Cash" ] [ Html.text "Cash" ]
                , option [ value "/Inventory" ] [ Html.text "Inventory" ]
                , option [ value "/Pending Trades" ] [ Html.text "Pending Trades" ]
                ]
            , label [ id "central-bank-select-label", for "central-bank-select", class "l-d" ] [ Html.text "Is Counterparty a Central Bank?:" ]
            , select [ id "central-bank-select", onInput SetDictValueBank, class "dropdown" ]
                [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                , option [ value "Is Segregated Cash/True" ] [ Html.text "Yes" ]
                , option [ value "Is On Shore/False" ] [ Html.text "No" ]
                ]
            , Html.div [ id "central-bank-yes-child" ]
                [ label [ id "seg-cash-select-label", for "seg-cash-select", class "l-d" ] [ Html.text "Is Segregated Cash?:" ]
                , select [ id "seg-cash-select", onInput SetDictValueSegCash, class "dropdown" ]
                    [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                    , option [ value "Classify By Counter Party ID/True" ] [ Html.text "Yes" ]
                    , option [ value "Classify By Counter Party ID/False" ] [ Html.text "No" ]
                    ]
                , label [ id "code-select-1-label", for "code-select-1", class "l-d" ] [ Html.text "Select Counterparty ID:" ]
                , select [ id "code-select-1", onInput SetDictValueCode, class "dropdown" ]
                    [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                    , option [ value "I.A.4.1/FRD" ] [ Html.text "FRD" ]
                    , option [ value "I.A.4.2/BOE" ] [ Html.text "BOE" ]
                    , option [ value "I.A.4.3/SNB" ] [ Html.text "SNB" ]
                    , option [ value "I.A.4.4/ECB" ] [ Html.text "ECB" ]
                    , option [ value "I.A.4.5/BOJ" ] [ Html.text "BOJ" ]
                    , option [ value "I.A.4.6/RBA" ] [ Html.text "RBA" ]
                    , option [ value "I.A.4.7/BOC" ] [ Html.text "BOC" ]
                    , option [ value "I.A.4.8/other" ] [ Html.text "other" ]
                    ]
                , label [ id "code-select-2-label", for "code-select-2", class "l-d" ] [ Html.text "Select Counterparty ID:" ]
                , select [ id "code-select-2", onInput SetDictValueCode, class "dropdown" ]
                    [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                    , option [ value "I.A.3.1/FRD" ] [ Html.text "FRD" ]
                    , option [ value "I.A.3.2/BOE" ] [ Html.text "BOE" ]
                    , option [ value "I.A.3.3/SNB" ] [ Html.text "SNB" ]
                    , option [ value "I.A.3.4/ECB" ] [ Html.text "ECB" ]
                    , option [ value "I.A.3.5/BOJ" ] [ Html.text "BOJ" ]
                    , option [ value "I.A.3.6/RBA" ] [ Html.text "RBA" ]
                    , option [ value "I.A.3.7/BOC" ] [ Html.text "BOC" ]
                    , option [ value "I.A.3.8/other" ] [ Html.text "other" ]
                    ]
                ]
            , Html.div [ id "central-bank-no-child" ]
                [ label [ id "on-shore-select-label", for "on-shore-select", class "l-d" ] [ Html.text "On or Off Shore?: " ]
                , select [ id "on-shore-select", onInput SetDictValueShore, class "dropdown" ]
                    [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                    , option [ value "Is NetUsd Amount Negative/True" ] [ Html.text "On" ]
                    , option [ value "Is NetUsd Amount Negative/False" ] [ Html.text "Off" ]
                    ]
                , label [ id "negative-select-label", for "negative-select", class "l-d" ] [ Html.text "NetUSD Amount: " ]
                , select [ id "negative-select", onInput SetDictValueNegative, class "dropdown" ]
                    [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                    , option [ value "O.W.9/True" ] [ Html.text "Negative" ]
                    , option [ value "Is Feed44 and CostCenter Not 5C55/False" ] [ Html.text "Positive" ]
                    ]
                , Html.div [ id "negative-no-child" ]
                    [ label [ id "negative-no-child-select-label", for "negative-no-child-select", class "l-d" ] [ Html.text "Is Cost Center Not 5C55: " ]
                    , select [ id "negative-no-child-select", onInput SetDictValueFeed, class "dropdown" ]
                        [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                        , option [ value "I.U.1/True" ] [ Html.text "Yes" ]
                        , option [ value "I.U.4/False" ] [ Html.text "No" ]
                        ]
                    ]
                , label [ id "negative-select-2-label", for "negative-select-2", class "l-d" ] [ Html.text "NetUSD Amount: " ]
                , select [ id "negative-select-2", onInput SetDictValueNegative, class "dropdown" ]
                    [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                    , option [ value "O.W.10/True" ] [ Html.text "Negative" ]
                    , option [ value "Is Feed44 and CostCenter Not 5C55/False" ] [ Html.text "Positive" ]
                    ]
                , Html.div [ id "negative-no-child-2" ]
                    [ label [ id "negative-no-child-select-2-label", for "negative-no-child-select-2", class "l-d" ] [ Html.text "Is Cost Center Not 5C55: " ]
                    , select [ id "negative-no-child-select-2", onInput SetDictValueFeed, class "dropdown" ]
                        [ option [ value "", disabled True, selected True ] [ Html.text "Select" ]
                        , option [ value "I.U.2/True" ] [ Html.text "Yes" ]
                        , option [ value "I.U.4/False" ] [ Html.text "No" ]
                        ]
                    ]
                ]
            ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map TreeViewMsg (TreeView.subscriptions2 model.treeModel)



-- converts to a list with maybe pattern to enable conversion from IR to decision tree represented by root node


toMaybeList : List ( Pattern (), Value () () ) -> List ( Maybe (Pattern ()), Value () () )
toMaybeList list =
    let
        patterns =
            List.map Tuple.first list

        maybePatterns =
            List.map Just patterns

        values =
            List.map Tuple.second list
    in
    List.map2 Tuple.pair maybePatterns values



-- converts a list of values to a list of tree nodes and nodedata


listToNode : List (Value () ()) -> Dict String String -> List (Tree.Node NodeData)
listToNode values dict =
    let
        uids =
            List.range 1 (List.length values)
    in
    List.map2 (\value uid -> toTranslate value uid dict) values uids



-- translates value to tree node and node data


toTranslate : Value () () -> Int -> Dict String String -> Tree.Node NodeData
toTranslate value uid dict =
    let
        newDict =
            convertToDict
                (Dict.fromList
                    (List.append
                        [ ( "Classify By Position Type", "" ) ]
                        (List.map helper (List.map (split "/") (Dict.values dict)))
                    )
                )
    in
    translation ( Nothing, value ) (fromInt uid) False newDict



-- checks if parent is highlighted and runs an evaluate highlight to see if the current node should be highlighted


getCurrentHighlightState : Bool -> Dict Name (Value () ()) -> Maybe (Pattern ()) -> Value () () -> String -> Bool
getCurrentHighlightState previous dict pattern subject uid =
    if Dict.size dict > 1 then
        if String.length uid == 1 then
            True

        else if previous then
            evaluateHighlight dict (Value.toString subject) (withDefault (WildcardPattern ()) pattern)

        else
            False

    else
        False



-- takes in the tuple and recursively matches whether it is and If Then Else, Pattern Match, or Value
-- traces to the leaves of the tree and then returns a root node that represents the entire decision tree


translation : ( Maybe (Pattern ()), Value () () ) -> String -> Bool -> Dict Name (Value () ()) -> Tree.Node NodeData
translation ( pattern, value ) uid previousHighlightState dict =
    case value of
        Value.IfThenElse _ condition thenBranch elseBranch ->
            let
                currentHighlightState : Bool
                currentHighlightState =
                    getCurrentHighlightState previousHighlightState dict pattern condition uid

                data =
                    NodeData uid (Value.toString condition) pattern currentHighlightState

                uids =
                    createUIDS 2 uid

                list =
                    [ ( Just (Value.LiteralPattern () (BoolLiteral True)), thenBranch ), ( Just (Value.LiteralPattern () (BoolLiteral False)), elseBranch ) ]

                children : List (Tree.Node NodeData)
                children =
                    List.map2 (\myList myUID -> translation myList myUID currentHighlightState dict) list uids
            in
            Tree.Node
                { data = data
                , children = children
                }

        Value.PatternMatch tpe param patterns ->
            let
                currentHighlightState : Bool
                currentHighlightState =
                    getCurrentHighlightState previousHighlightState dict pattern param uid

                data =
                    NodeData uid (Value.toString param) pattern currentHighlightState

                maybePatterns =
                    toMaybeList patterns

                uids =
                    createUIDS (List.length maybePatterns) uid

                children : List (Tree.Node NodeData)
                children =
                    List.map2 (\myList myUID -> translation myList myUID currentHighlightState dict) maybePatterns uids
            in
            Tree.Node
                { data = data
                , children = children
                }

        _ ->
            let
                currentHighlightState : Bool
                currentHighlightState =
                    getCurrentHighlightState previousHighlightState dict pattern value uid
            in
            Tree.Node { data = NodeData uid (Value.toString value) pattern currentHighlightState, children = [] }



-- creates UID in the formation 1 and 1.1 and 1.1.1


createUIDS : Int -> String -> List String
createUIDS range currentUID =
    let
        intRange =
            List.range 1 range

        stringRange =
            List.map fromInt intRange

        appender int =
            String.append (currentUID ++ ".") int
    in
    List.map appender stringRange


type NodeDataMsg
    = EditContent String String -- uid content



-- convert the dictionary of strings to a dictionary of name values


convertToDict : Dict String String -> Dict Name (Value ta ())
convertToDict dict =
    let
        dictList =
            Dict.toList dict
    in
    Dict.fromList (List.map convertToDictHelper dictList)


convertToDictHelper : ( String, String ) -> ( Name, Value ta () )
convertToDictHelper ( k, v ) =
    case v of
        "True" ->
            ( Name.fromString k, Value.Literal () (BoolLiteral True) )

        "False" ->
            ( Name.fromString k, Value.Literal () (BoolLiteral False) )

        _ ->
            ( Name.fromString k, Value.Literal () (StringLiteral v) )



-- returns the HTML msg based on whether or not a node is highlighted


viewNodeData : Maybe NodeData -> Tree.Node NodeData -> Html.Html NodeDataMsg
viewNodeData selectedNode node =
    let
        nodeData =
            Tree.dataOf node
    in
    if nodeData.highlight then
        Html.div
            [ class "highlighted-node"
            ]
            [ Html.text (nodeLabel node)
            ]

    else
        Html.text (nodeLabel node)


helper : List String -> ( String, String )
helper l =
    case l of
        [ s1, s2 ] ->
            ( s1, s2 )

        _ ->
            ( "oh", "no" )
