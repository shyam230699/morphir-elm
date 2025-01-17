module Morphir.Correctness.Codec exposing (..)

import Dict
import Json.Decode as Decode exposing (string)
import Json.Encode as Encode
import Morphir.Correctness.Test exposing (TestCase, TestCases, TestSuite)
import Morphir.IR as IR exposing (IR)
import Morphir.IR.FQName as FQName exposing (FQName)
import Morphir.IR.FQName.CodecV1 as FQName exposing (decodeFQName)
import Morphir.IR.Name exposing (Name)
import Morphir.IR.Type exposing (Type)
import Morphir.IR.Type.DataCodec as DataCodec
import Morphir.IR.Value as Value exposing (RawValue)
import Morphir.ListOfResults as ListOfResults


encodeTestSuite : IR -> TestSuite -> Result String Encode.Value
encodeTestSuite ir testSuite =
    testSuite
        |> Dict.toList
        |> List.map
            (\( fQName, testCases ) ->
                case IR.lookupValueSpecification fQName ir of
                    Just valueSpec ->
                        testCases
                            |> encodeTestCases ir valueSpec
                            |> Result.map
                                (\encodedList ->
                                    Encode.list identity
                                        [ FQName.encodeFQName fQName
                                        , encodedList
                                        ]
                                )

                    Nothing ->
                        Err "Cannot find function in IR"
            )
        |> ListOfResults.liftFirstError
        |> Result.map (Encode.list identity)


decodeTestSuite : IR -> Decode.Decoder TestSuite
decodeTestSuite ir =
    Decode.map Dict.fromList
        (Decode.list
            (Decode.index 0 decodeFQName
                |> Decode.andThen
                    (\fQName ->
                        case IR.lookupValueSpecification fQName ir of
                            Just valueSpec ->
                                Decode.index 1
                                    (Decode.list (decodeTestCase ir valueSpec)
                                        |> Decode.map (Tuple.pair fQName)
                                    )

                            Nothing ->
                                Decode.fail ("Cannot find " ++ FQName.toString fQName)
                    )
            )
        )


encodeTestCases : IR -> Value.Specification () -> TestCases -> Result String Encode.Value
encodeTestCases ir valueSpec testCases =
    let
        encodeInput : List ( Name, Type () ) -> TestCase -> Result String Encode.Value
        encodeInput inputTypes testCase =
            List.map2
                (\( _, tpe ) testcase ->
                    DataCodec.encodeData ir tpe
                        |> Result.andThen
                            (\encoder ->
                                testcase |> encoder
                            )
                )
                inputTypes
                testCase.inputs
                |> ListOfResults.liftFirstError
                |> Result.map (Encode.list identity)
    in
    testCases
        |> List.map
            (\testCase ->
                let
                    ( inputEncoder, outputEncoder ) =
                        ( encodeInput
                            valueSpec.inputs
                            testCase
                        , DataCodec.encodeData ir valueSpec.output
                            |> Result.andThen
                                (\encoder ->
                                    testCase.expectedOutput |> encoder
                                )
                        )
                in
                Result.map2
                    (\inpEncoder outEncoder ->
                        Encode.object
                            [ ( "inputs", inpEncoder )
                            , ( "expectedOutput", outEncoder )
                            , ( "description", testCase.description |> Encode.string )
                            ]
                    )
                    inputEncoder
                    outputEncoder
            )
        |> ListOfResults.liftFirstError
        |> Result.map (Encode.list identity)


decodeTestCase : IR -> Value.Specification () -> Decode.Decoder TestCase
decodeTestCase ir valueSpec =
    let
        resultToFailure : Result String (Decode.Decoder a) -> Decode.Decoder a
        resultToFailure result =
            case result of
                Ok decoder ->
                    decoder

                Err error ->
                    Decode.fail error
    in
    Decode.map3 Morphir.Correctness.Test.TestCase
        (Decode.field "inputs"
            (valueSpec.inputs
                |> List.foldl
                    (\( argName, argType ) ( index, decoderSoFar ) ->
                        ( index + 1
                        , decoderSoFar
                            |> Decode.andThen
                                (\inputsSoFar ->
                                    Decode.index index
                                        (DataCodec.decodeData ir argType
                                            |> resultToFailure
                                            |> Decode.map
                                                (\input ->
                                                    List.append inputsSoFar [ input ]
                                                )
                                        )
                                )
                        )
                    )
                    ( 0, Decode.succeed [] )
                |> Tuple.second
            )
        )
        (Decode.field "expectedOutput" (DataCodec.decodeData ir valueSpec.output |> resultToFailure))
        (Decode.field "description" string)
